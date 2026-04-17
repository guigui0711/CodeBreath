// Popover panel: today's stats, category cards, next reminder, pause/practice.

import SwiftUI

struct PopoverView: View {
    @ObservedObject var storage: StorageManager
    @ObservedObject var scheduler: SchedulerEngine
    @State private var now = Date()

    private var locale: AppLocale { storage.config.locale }

    var body: some View {
        let stats = storage.todayStats()
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locale == .zh ? "今日完成" : "Today")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(stats.completed)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("/ \(stats.total)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Category row
            HStack(spacing: 8) {
                categoryCard(symbol: "eye.fill", tint: .blue,
                             label: locale == .zh ? "护眼" : "Eye",
                             stats: stats, key: "eye")
                categoryCard(symbol: "figure.cooldown", tint: .purple,
                             label: locale == .zh ? "颈肩" : "Neck",
                             stats: stats, key: "neck")
                categoryCard(symbol: "figure.walk", tint: .green,
                             label: locale == .zh ? "活动" : "Move",
                             stats: stats, key: "sedentary")
            }

            Divider()

            // 7-day trend
            let rates = storage.weeklyCompletionRates()
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locale == .zh ? "最近 7 天" : "Last 7 days")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(Int((rates.reduce(0, +) / Double(max(rates.count, 1))) * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
                Sparkline(values: rates)
                    .frame(height: 28)
            }

            Divider()

            // Next reminder
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(locale == .zh ? "下次提醒" : "Next reminder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(nextLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                }
                Spacer()
            }

            // Buttons
            HStack(spacing: DS.Spacing.sm) {
                Button(action: togglePause) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: scheduler.isPaused ? "play.fill" : "pause.fill")
                        Text(pauseButtonLabel)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(
                    background: Color.primary.opacity(0.08),
                    tint: .primary,
                    cornerRadius: DS.Radius.sm
                ))

                Button(action: { scheduler.triggerNow() }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "bolt.fill")
                        Text(locale == .zh ? "现在练习" : "Practice now")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(
                    background: Color.accentColor,
                    tint: .white,
                    cornerRadius: DS.Radius.sm
                ))
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 320)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    private func categoryCard(symbol: String, tint: Color, label: String, stats: DayStats, key: String) -> some View {
        let bucket = stats.byCategory[key] ?? (completed: 0, skipped: 0, notified: 0)
        let total = bucket.completed + bucket.skipped
        return VStack(spacing: DS.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundColor(tint)
            Text("\(bucket.completed)/\(total)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var nextLabel: String {
        if scheduler.isPaused {
            if let until = scheduler.pauseUntil {
                let mins = max(0, Int(until.timeIntervalSince(now) / 60))
                return (locale == .zh ? "已暂停 · 剩 " : "Paused · ") + "\(mins)m"
            }
            return locale == .zh ? "已暂停" : "Paused"
        }
        guard let next = scheduler.nextReminderAt else {
            return locale == .zh ? "—" : "—"
        }
        let interval = next.timeIntervalSince(now)
        if interval <= 0 { return locale == .zh ? "即将" : "Soon" }
        let mins = Int(interval / 60)
        let secs = Int(interval) % 60
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return "\(h)h \(m)m"
        }
        return "\(mins)m \(secs)s"
    }

    private var pauseButtonLabel: String {
        if scheduler.isPaused {
            return locale == .zh ? "继续" : "Resume"
        }
        return locale == .zh ? "暂停 30 分钟" : "Pause 30 min"
    }

    private func togglePause() {
        if scheduler.isPaused {
            scheduler.resume()
        } else {
            scheduler.pause(for: 30 * 60)
        }
    }

    private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Double]   // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Baseline
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

                // Line
                Path { p in
                    guard values.count > 1 else { return }
                    let w = geo.size.width / CGFloat(values.count - 1)
                    let h = geo.size.height
                    p.move(to: CGPoint(x: 0, y: h * (1 - CGFloat(values[0]))))
                    for i in 1..<values.count {
                        p.addLine(to: CGPoint(x: CGFloat(i) * w, y: h * (1 - CGFloat(values[i]))))
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Dots
                ForEach(values.indices, id: \.self) { i in
                    let w = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                        .position(x: CGFloat(i) * w, y: geo.size.height * (1 - CGFloat(values[i])))
                }
            }
        }
    }
}
