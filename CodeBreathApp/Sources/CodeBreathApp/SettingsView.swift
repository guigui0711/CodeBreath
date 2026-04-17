// Settings: tabbed pane bound to StorageManager.config.

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var storage: StorageManager

    var body: some View {
        TabView {
            GeneralTab(storage: storage)
                .tabItem { Label("General", systemImage: "gearshape") }
            RemindersTab(storage: storage)
                .tabItem { Label("Reminders", systemImage: "bell") }
            AppearanceTab(storage: storage)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 480, height: 380)
        .padding()
    }
}

private struct GeneralTab: View {
    @ObservedObject var storage: StorageManager

    var body: some View {
        Form {
            Section {
                LabeledContent("Language") {
                    Picker("", selection: binding(\.language)) {
                        Text("中文").tag("zh")
                        Text("English").tag("en")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                LabeledContent("Launch at login") {
                    Toggle("", isOn: launchAtLoginBinding).labelsHidden()
                }
                LabeledContent("Notification sound") {
                    Picker("", selection: binding(\.notificationSound)) {
                        Text("Default").tag("default")
                        Text("Glass").tag("glass")
                        Text("Hero").tag("hero")
                        Text("Ping").tag("ping")
                        Text("None").tag("none")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            } footer: {
                Text("提醒触发时的系统提示音。选择 None 静音触发。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ kp: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding(
            get: { storage.config[keyPath: kp] },
            set: { storage.config[keyPath: kp] = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { storage.config.launchAtLogin },
            set: { newValue in
                if #available(macOS 13.0, *) {
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        storage.config.launchAtLogin = newValue
                    } catch {
                        NSLog("Launch-at-login toggle failed: \(error)")
                        // Leave config unchanged on failure so UI reflects actual state.
                    }
                } else {
                    storage.config.launchAtLogin = newValue
                }
            }
        )
    }
}

private struct RemindersTab: View {
    @ObservedObject var storage: StorageManager

    var body: some View {
        Form {
            Section {
                LabeledContent("Eye + neck") {
                    Stepper(value: binding(\.eyeNeckIntervalMinutes), in: 10...120, step: 5) {
                        Text("\(storage.config.eyeNeckIntervalMinutes) min")
                            .monospacedDigit()
                    }
                }
                LabeledContent("Sedentary") {
                    Stepper(value: binding(\.sedentaryIntervalMinutes), in: 30...180, step: 10) {
                        Text("\(storage.config.sedentaryIntervalMinutes) min")
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Intervals")
            } footer: {
                Text("决定多久触发一次提醒。间隔过短会打断心流，过长则失去提示作用。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Start") {
                    TimePickerField(text: binding(\.workingHoursStart))
                }
                LabeledContent("End") {
                    TimePickerField(text: binding(\.workingHoursEnd))
                }
            } header: {
                Text("Working hours")
            } footer: {
                Text("仅在此时段内触发提醒。Noon 提醒不受限制。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Enabled") {
                    Toggle("", isOn: binding(\.noonReminderEnabled)).labelsHidden()
                }
                LabeledContent("Time") {
                    TimePickerField(text: binding(\.noonReminderTime))
                }
                .disabled(!storage.config.noonReminderEnabled)
            } header: {
                Text("Noon outdoor")
            } footer: {
                Text("每天在指定时间提醒你出门晒太阳 15 分钟——控制近视进展最有效的干预。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Enabled") {
                    Toggle("", isOn: binding(\.dailyReportEnabled)).labelsHidden()
                }
                LabeledContent("Time") {
                    TimePickerField(text: binding(\.dailyReportTime))
                }
                .disabled(!storage.config.dailyReportEnabled)
            } header: {
                Text("Daily report")
            } footer: {
                Text("下班时推送一条今日完成情况汇总通知。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ kp: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding(
            get: { storage.config[keyPath: kp] },
            set: { storage.config[keyPath: kp] = $0 }
        )
    }
}

private struct AppearanceTab: View {
    @ObservedObject var storage: StorageManager

    var body: some View {
        Form {
            Section {
                LabeledContent("Position") {
                    Picker("", selection: binding(\.floatingWindowPosition)) {
                        Text("Center").tag("center")
                        Text("Top-right").tag("top-right")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            } header: {
                Text("Floating window")
            } footer: {
                Text("提醒浮窗出现在屏幕的哪个位置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ kp: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding(
            get: { storage.config[keyPath: kp] },
            set: { storage.config[keyPath: kp] = $0 }
        )
    }
}

// MARK: - Time picker field

private struct TimePickerField: View {
    @Binding var text: String

    var body: some View {
        DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
            .labelsHidden()
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                let parts = text.split(separator: ":").compactMap { Int($0) }
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = parts.count > 0 ? parts[0] : 9
                comps.minute = parts.count > 1 ? parts[1] : 0
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                text = String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
            }
        )
    }
}
