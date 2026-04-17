// Daily report: optional end-of-day summary notification.

import Foundation
import Combine
import UserNotifications

final class DailyReportScheduler {
    private let storage: StorageManager
    private var timer: Timer?
    private var cancellable: AnyCancellable?

    init(storage: StorageManager) {
        self.storage = storage
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        self.cancellable = storage.$config
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.reschedule() }
        reschedule()
    }

    func reschedule() {
        timer?.invalidate(); timer = nil
        let cfg = storage.config
        guard cfg.dailyReportEnabled, let fireAt = nextDate(for: cfg.dailyReportTime) else { return }
        let delay = max(1, fireAt.timeIntervalSinceNow)
        let t = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.postReport()
            self?.reschedule()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func postReport() {
        let stats = storage.todayStats()
        let streak = storage.streakCount()

        let content = UNMutableNotificationContent()
        content.title = storage.config.locale == .zh ? "CodeBreath 今日总结" : "CodeBreath daily summary"

        let line1 = storage.config.locale == .zh
            ? "今日完成 \(stats.completed)/\(stats.total)，连续 \(streak) 天"
            : "Completed \(stats.completed)/\(stats.total) today · \(streak)-day streak"

        var categoryLines: [String] = []
        for key in ["eye", "neck", "sedentary", "noon"] {
            if let b = stats.byCategory[key], b.completed + b.skipped > 0 {
                categoryLines.append("\(key) \(b.completed)/\(b.completed + b.skipped)")
            }
        }
        content.body = ([line1] + categoryLines).joined(separator: "\n")
        content.sound = .default

        let req = UNNotificationRequest(identifier: "codebreath.daily.\(UUID())", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func nextDate(for hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.second = 0
        guard var d = cal.date(from: comps) else { return nil }
        if d <= Date() { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        return d
    }
}
