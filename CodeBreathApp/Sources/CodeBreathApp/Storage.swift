// Storage manager: config + daily logs + migration from ~/.codebreath/.

import Foundation
import Combine

// MARK: - Config

struct AppConfig: Codable, Equatable {
    var eyeNeckIntervalMinutes: Int = 30
    var sedentaryIntervalMinutes: Int = 60
    var workingHoursStart: String = "09:00"
    var workingHoursEnd: String = "19:00"
    var noonReminderEnabled: Bool = true
    var noonReminderTime: String = "12:00"
    var dailyReportEnabled: Bool = true
    var dailyReportTime: String = "18:30"
    var language: String = "zh"
    var launchAtLogin: Bool = false
    var floatingWindowPosition: String = "center"   // "center" | "top-right"
    var notificationSound: String = "default"        // "default"|"glass"|"hero"|"ping"|"none"

    var locale: AppLocale { AppLocale(rawValue: language) ?? .zh }
}

// MARK: - Log event

struct LogEvent: Codable, Hashable {
    let timestamp: Date
    let category: String     // "eye" | "neck" | "sedentary" | "noon" | "eye_neck"
    let tipName: String
    let action: String       // "notified" | "completed" | "skipped"
}

// MARK: - Stats

struct DayStats {
    var completed: Int = 0
    var skipped: Int = 0
    var byCategory: [String: (completed: Int, skipped: Int)] = [:]

    var total: Int { completed + skipped }
}

// MARK: - StorageManager

final class StorageManager: ObservableObject {
    @Published var config: AppConfig {
        didSet { if config != oldValue { saveConfig() } }
    }
    /// Bumped whenever a log event is written. Views that read today's stats
    /// (menu bar counter, popover) observe this to refresh; otherwise the
    /// 🫁 N/M pill freezes between config changes.
    @Published private(set) var logVersion: Int = 0

    private let ioQueue = DispatchQueue(label: "com.codebreath.storage.io")
    private let appSupportDir: URL
    private let configURL: URL
    private let logsDir: URL
    private let migrationSentinel: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CodeBreath", isDirectory: true)
        self.appSupportDir = base
        self.configURL = base.appendingPathComponent("config.json")
        self.logsDir = base.appendingPathComponent("logs", isDirectory: true)
        self.migrationSentinel = base.appendingPathComponent(".migrated")

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: migrationSentinel.path) {
            Self.migrateFromLegacy(into: base, logsDir: logsDir)
            fm.createFile(atPath: migrationSentinel.path, contents: Data())
        }

        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder.iso8601.decode(AppConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = AppConfig()
        }
        saveConfig()
    }

    private func saveConfig() {
        guard let data = try? JSONEncoder.pretty.encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    func append(event: LogEvent) {
        ioQueue.sync {
            let url = logURL(for: event.timestamp)
            var events = loadEvents(at: url)
            events.append(event)
            if let data = try? JSONEncoder.pretty.encode(events) {
                try? data.write(to: url, options: .atomic)
            }
        }
        DispatchQueue.main.async { [weak self] in self?.logVersion &+= 1 }
    }

    func todayStats() -> DayStats {
        statsForEvents(loadEvents(at: logURL(for: Date())))
    }

    /// Past 7 days (oldest → today) completion rate: completed / (completed + skipped).
    /// Empty days return 0.
    func weeklyCompletionRates() -> [Double] {
        let cal = Calendar.current
        var result: [Double] = []
        for i in (0...6).reversed() {
            let day = cal.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let events = loadEvents(at: logURL(for: day))
            let completed = events.filter { $0.action == "completed" }.count
            let skipped = events.filter { $0.action.hasPrefix("skipped") }.count
            let total = completed + skipped
            result.append(total == 0 ? 0 : Double(completed) / Double(total))
        }
        return result
    }

    func streakCount() -> Int {
        var streak = 0
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var allowedTodayNoCompletion = true
        while streak < 365 {
            let events = loadEvents(at: logURL(for: day))
            if events.contains(where: { $0.action == "completed" }) {
                streak += 1
                allowedTodayNoCompletion = false
            } else if allowedTodayNoCompletion && cal.isDateInToday(day) {
                allowedTodayNoCompletion = false
            } else {
                break
            }
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    private func logURL(for date: Date) -> URL {
        logsDir.appendingPathComponent("\(Self.ymd(date)).json")
    }

    private func loadEvents(at url: URL) -> [LogEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.iso8601.decode([LogEvent].self, from: data)
        else { return [] }
        return decoded
    }

    private func statsForEvents(_ events: [LogEvent]) -> DayStats {
        var stats = DayStats()
        for ev in events {
            var bucket = stats.byCategory[ev.category] ?? (0, 0)
            switch ev.action {
            case "completed": stats.completed += 1; bucket.completed += 1
            case _ where ev.action.hasPrefix("skipped"):
                stats.skipped += 1; bucket.skipped += 1
            default: break
            }
            stats.byCategory[ev.category] = bucket
        }
        return stats
    }

    static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func migrateFromLegacy(into newBase: URL, logsDir: URL) {
        let fm = FileManager.default
        let legacyBase = fm.homeDirectoryForCurrentUser.appendingPathComponent(".codebreath", isDirectory: true)
        let legacyConfig = legacyBase.appendingPathComponent("config.json")
        let legacyLogs = legacyBase.appendingPathComponent("logs", isDirectory: true)

        guard fm.fileExists(atPath: legacyBase.path) else { return }

        if let data = try? Data(contentsOf: legacyConfig),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            var cfg = AppConfig()
            if let v = json["eye_neck_interval_minutes"] as? Int { cfg.eyeNeckIntervalMinutes = v }
            if let v = json["sedentary_interval_minutes"] as? Int { cfg.sedentaryIntervalMinutes = v }
            if let v = json["working_hours_start"] as? String { cfg.workingHoursStart = v }
            if let v = json["working_hours_end"] as? String { cfg.workingHoursEnd = v }
            if let v = json["noon_reminder_enabled"] as? Bool { cfg.noonReminderEnabled = v }
            if let v = json["noon_reminder_time"] as? String { cfg.noonReminderTime = v }
            if let v = json["daily_report_enabled"] as? Bool { cfg.dailyReportEnabled = v }
            if let v = json["daily_report_time"] as? String { cfg.dailyReportTime = v }
            if let v = json["language"] as? String { cfg.language = v }
            if let v = json["notification_sound"] as? String { cfg.notificationSound = v }
            if let data = try? JSONEncoder.pretty.encode(cfg) {
                try? data.write(to: newBase.appendingPathComponent("config.json"))
            }
        }

        if let files = try? fm.contentsOfDirectory(at: legacyLogs, includingPropertiesForKeys: nil) {
            for src in files where src.pathExtension == "json" {
                let dst = logsDir.appendingPathComponent(src.lastPathComponent)
                if !fm.fileExists(atPath: dst.path) {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
        }
    }
}

// MARK: - JSON helpers

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
