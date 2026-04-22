// Scheduler engine: three tracks (eye+neck, sedentary, noon), working hours, merge window, pause/resume.

import Foundation
import Combine
import AppKit

final class SchedulerEngine: ObservableObject {
    @Published private(set) var nextReminderAt: Date?
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var pauseUntil: Date?

    private let storage: StorageManager
    private weak var presenter: ReminderPresenter?
    private let flowDetector = FlowDetector()
    private var recentSkipCount: Int = 0

    private var eyeNeckTimer: Timer?
    private var sedentaryTimer: Timer?
    private var noonTimer: Timer?
    private var tickTimer: Timer?

    private var lastFireAt: Date?
    private let mergeWindowSeconds: TimeInterval = 60

    private var configCancellable: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?

    init(storage: StorageManager, presenter: ReminderPresenter) {
        self.storage = storage
        self.presenter = presenter
        self.configCancellable = storage.$config
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.restart() }
        self.restart()

        // Periodic tick to recompute nextReminderAt and clear pause.
        let tt = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tt, forMode: .common)
        tickTimer = tt

        // Sleep/wake handling: rebuild timers after wake, stop while sleeping.
        let wsCenter = NSWorkspace.shared.notificationCenter
        wakeObserver = wsCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.restart()
        }
        sleepObserver = wsCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopTimers()
        }
    }

    deinit {
        let wsCenter = NSWorkspace.shared.notificationCenter
        if let o = wakeObserver { wsCenter.removeObserver(o) }
        if let o = sleepObserver { wsCenter.removeObserver(o) }
        tickTimer?.invalidate()
        stopTimers()
    }

    // MARK: - Public controls

    func pause(for duration: TimeInterval?) {
        isPaused = true
        if let duration = duration {
            pauseUntil = Date().addingTimeInterval(duration)
        } else {
            pauseUntil = nil
        }
        stopTimers()
        updateNextReminderAt()
    }

    func resume() {
        isPaused = false
        pauseUntil = nil
        restart()
    }

    func triggerNow() {
        // Manual trigger bypasses flow protection — user explicitly asked for it.
        let tips = ContentLibrary.combinedEyeAndNeck()
        let primary = (tips.count == 1 && tips[0].kind == .compound) ? "combo" : "eye_neck"
        present(tips: tips, primaryCategory: primary)
    }

    // MARK: - Timer setup

    private func restart() {
        stopTimers()
        guard !isPaused else {
            updateNextReminderAt()
            return
        }
        let cfg = storage.config

        let eyeNeckInterval = TimeInterval(max(1, cfg.eyeNeckIntervalMinutes) * 60)
        let en = Timer(timeInterval: eyeNeckInterval, repeats: true) { [weak self] _ in
            self?.fireEyeNeck()
        }
        RunLoop.main.add(en, forMode: .common)
        eyeNeckTimer = en

        let sedInterval = TimeInterval(max(1, cfg.sedentaryIntervalMinutes) * 60)
        let st = Timer(timeInterval: sedInterval, repeats: true) { [weak self] _ in
            self?.fireSedentary()
        }
        RunLoop.main.add(st, forMode: .common)
        sedentaryTimer = st

        scheduleNoonTimer()
        updateNextReminderAt()
    }

    private func stopTimers() {
        eyeNeckTimer?.invalidate(); eyeNeckTimer = nil
        sedentaryTimer?.invalidate(); sedentaryTimer = nil
        noonTimer?.invalidate(); noonTimer = nil
    }

    private func scheduleNoonTimer() {
        let cfg = storage.config
        guard cfg.noonReminderEnabled else { return }
        guard let fireAt = nextDateMatching(timeString: cfg.noonReminderTime) else { return }
        let delay = fireAt.timeIntervalSinceNow
        let nt = Timer(timeInterval: max(1, delay), repeats: false) { [weak self] _ in
            self?.fireNoon()
            self?.scheduleNoonTimer()
        }
        RunLoop.main.add(nt, forMode: .common)
        noonTimer = nt
    }

    private func tick() {
        if let until = pauseUntil, Date() >= until {
            resume()
            return
        }
        updateNextReminderAt()
    }

    // MARK: - Firing

    private func fireEyeNeck() {
        guard shouldFire() else { return }
        if let defer_ = flowDetector.shouldDeferReminder() {
            storage.append(event: LogEvent(timestamp: Date(), category: "eye_neck", tipName: "__deferred__", action: "deferred"))
            DispatchQueue.main.asyncAfter(deadline: .now() + defer_) { [weak self] in self?.fireEyeNeck() }
            return
        }
        let tips = ContentLibrary.combinedEyeAndNeck()
        // Track-level log label: "combo" when the selector produced a single
        // compound move; "eye_neck" for the legacy 3-step fallback.
        let primary = (tips.count == 1 && tips[0].kind == .compound) ? "combo" : "eye_neck"
        present(tips: tips, primaryCategory: primary)
    }

    private func fireSedentary() {
        guard shouldFire() else { return }
        if let defer_ = flowDetector.shouldDeferReminder() {
            storage.append(event: LogEvent(timestamp: Date(), category: "sedentary", tipName: "__deferred__", action: "deferred"))
            DispatchQueue.main.asyncAfter(deadline: .now() + defer_) { [weak self] in self?.fireSedentary() }
            return
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let tip = ContentLibrary.sedentaryBreak(forHour: hour)
        present(tips: [tip], primaryCategory: "sedentary")
    }

    private func fireNoon() {
        guard shouldFire(ignoreWorkingHours: true) else { return }
        let tip = ContentLibrary.noonReminder()
        present(tips: [tip], primaryCategory: "noon")
    }

    private func shouldFire(ignoreWorkingHours: Bool = false) -> Bool {
        if isPaused { return false }
        if !ignoreWorkingHours && !isWithinWorkingHours() { return false }
        return true
    }

    private func present(tips: [Tip], primaryCategory: String) {
        let now = Date()

        // Log each tip as notified.
        for t in tips {
            storage.append(event: LogEvent(timestamp: now, category: t.category.rawValue, tipName: t.name.en, action: "notified"))
        }

        // Merge: if a window is already visible and within merge window, append steps.
        let merged: Bool
        if let last = lastFireAt, now.timeIntervalSince(last) < mergeWindowSeconds,
           presenter?.appendIfVisible(tips: tips) == true {
            merged = true
        } else {
            merged = false
        }
        lastFireAt = now
        if merged { return }

        let locale = storage.config.locale
        let position = storage.config.floatingWindowPosition
        presenter?.present(
            tips: tips,
            position: position,
            locale: locale,
            onStep: { [weak self] tip, action in
                guard let self = self else { return }
                self.storage.append(event: LogEvent(
                    timestamp: Date(),
                    category: tip.category.rawValue,
                    tipName: tip.name.en,
                    action: action
                ))
                if action == "completed" {
                    self.recentSkipCount = 0
                } else if action == "skipped" {
                    self.recentSkipCount += 1
                    if self.recentSkipCount >= 3 {
                        self.recentSkipCount = 0
                        DispatchQueue.main.async { self.pause(for: 30 * 60) }
                    }
                }
            },
            onFinished: { [weak self] in
                self?.updateNextReminderAt()
            }
        )
    }

    // MARK: - Helpers

    private func updateNextReminderAt() {
        guard !isPaused else { nextReminderAt = nil; return }
        var candidates: [Date] = []
        if let t = eyeNeckTimer?.fireDate { candidates.append(t) }
        if let t = sedentaryTimer?.fireDate { candidates.append(t) }
        if let t = noonTimer?.fireDate { candidates.append(t) }
        nextReminderAt = candidates.min()
    }

    private func isWithinWorkingHours() -> Bool {
        let cfg = storage.config
        guard let start = parseHourMinute(cfg.workingHoursStart),
              let end = parseHourMinute(cfg.workingHoursEnd) else { return true }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let h = now.hour, let m = now.minute else { return true }
        let nowMin = h * 60 + m
        let startMin = start.h * 60 + start.m
        let endMin = end.h * 60 + end.m
        return nowMin >= startMin && nowMin <= endMin
    }

    private func parseHourMinute(_ s: String) -> (h: Int, m: Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func nextDateMatching(timeString: String) -> Date? {
        guard let hm = parseHourMinute(timeString) else { return nil }
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hm.h
        comps.minute = hm.m
        comps.second = 0
        guard var candidate = cal.date(from: comps) else { return nil }
        if candidate <= now {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}
