import SwiftUI

@main
struct CodeBreathApp: App {
    @StateObject private var storage = StorageManager()
    @StateObject private var runtime = Runtime()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(storage: storage, scheduler: runtime.scheduler(storage: storage))
        } label: {
            MenuBarView(storage: storage)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(storage: storage)
        }
    }
}

/// Holds objects that need @StateObject lifetime but depend on storage.
/// Lazily constructed on first access so Swift concurrency doesn't trip on init order.
final class Runtime: ObservableObject {
    private var _scheduler: SchedulerEngine?
    private var _presenter: FloatingReminderController?
    private var _dailyReport: DailyReportScheduler?

    func scheduler(storage: StorageManager) -> SchedulerEngine {
        if let s = _scheduler { return s }
        let presenter = FloatingReminderController()
        _presenter = presenter
        let s = SchedulerEngine(storage: storage, presenter: presenter)
        _scheduler = s
        _dailyReport = DailyReportScheduler(storage: storage)
        return s
    }
}
