// Floating reminder window: NSPanel + SwiftUI view with countdown ring, multi-step support.

import AppKit
import SwiftUI
import Combine

// MARK: - Presenter protocol (used by Scheduler)

protocol ReminderPresenter: AnyObject {
    /// Present a (possibly multi-step) reminder. `onComplete`/`onSkip` fire per step.
    /// `onFinished` fires after the last step closes (for whatever reason).
    func present(
        tips: [Tip],
        position: String,
        locale: AppLocale,
        onStep: @escaping (_ tip: Tip, _ action: String) -> Void,
        onFinished: @escaping () -> Void
    )

    /// Append extra steps to an already-visible window (merge window).
    func appendIfVisible(tips: [Tip]) -> Bool
}

// MARK: - Controller

final class FloatingReminderController: NSObject, ReminderPresenter {
    private var panel: NSPanel?
    private var viewModel: FloatingReminderViewModel?
    private var keyMonitor: Any?

    func present(
        tips: [Tip],
        position: String,
        locale: AppLocale,
        onStep: @escaping (Tip, String) -> Void,
        onFinished: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.close()

            let vm = FloatingReminderViewModel(
                tips: tips,
                locale: locale,
                onStep: onStep,
                onFinished: { [weak self] in
                    onFinished()
                    self?.close()
                }
            )
            self.viewModel = vm

            let rootView = FloatingReminderView(vm: vm)
            let hosting = NSHostingView(rootView: rootView)
            let size = NSSize(width: 420, height: 540)
            hosting.frame = NSRect(origin: .zero, size: size)

            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.hasShadow = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentView = hosting
            panel.isMovableByWindowBackground = true

            self.positionPanel(panel, position: position)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            NSApp.activate(ignoringOtherApps: false)
            self.panel = panel

            self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.panel != nil else { return event }
                // ESC (53) or Cmd+W
                if event.keyCode == 53 ||
                    (event.keyCode == 13 && event.modifierFlags.contains(.command)) {
                    self.viewModel?.close()
                    return nil
                }
                return event
            }
        }
    }

    func appendIfVisible(tips: [Tip]) -> Bool {
        guard let vm = viewModel, panel != nil else { return false }
        DispatchQueue.main.async { vm.appendSteps(tips) }
        return true
    }

    private func close() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        viewModel?.cancelTimers()
        if let panel = panel {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
        panel = nil
        viewModel = nil
    }

    private func positionPanel(_ panel: NSPanel, position: String) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let size = panel.frame.size
        let origin: NSPoint
        switch position {
        case "top-right":
            origin = NSPoint(x: vf.maxX - size.width - 24, y: vf.maxY - size.height - 24)
        default:
            origin = NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2)
        }
        panel.setFrameOrigin(origin)
    }
}

// MARK: - View model

final class FloatingReminderViewModel: ObservableObject {
    @Published var tips: [Tip]
    @Published var currentIndex: Int = 0
    @Published var secondsRemaining: Int
    @Published var countdownDone: Bool = false
    @Published var hasStarted: Bool = false
    @Published var showingSkipReason: Bool = false

    enum SkipReason: String, CaseIterable, Identifiable {
        case busy, notAtDesk, notInterested, later
        var id: String { rawValue }
        func label(_ locale: AppLocale) -> String {
            switch (self, locale) {
            case (.busy, .zh): return "太忙"
            case (.busy, .en): return "Too busy"
            case (.notAtDesk, .zh): return "不在工位"
            case (.notAtDesk, .en): return "Not at desk"
            case (.notInterested, .zh): return "不需要"
            case (.notInterested, .en): return "Don't need"
            case (.later, .zh): return "稍后再说"
            case (.later, .en): return "Later"
            }
        }
    }

    let locale: AppLocale
    private let onStep: (Tip, String) -> Void
    private let onFinished: () -> Void

    private var countdownTimer: Timer?
    private var idleTimer: Timer?
    private let idleTimeout: TimeInterval = 300  // 5-minute auto-skip

    init(tips: [Tip], locale: AppLocale, onStep: @escaping (Tip, String) -> Void, onFinished: @escaping () -> Void) {
        self.tips = tips
        self.locale = locale
        self.onStep = onStep
        self.onFinished = onFinished
        self.secondsRemaining = tips.first?.durationSeconds ?? 20
        startIdleWatchdog()
        // Countdown does NOT auto-start; user must tap "开始".
    }

    var currentTip: Tip { tips[currentIndex] }
    var progressLabel: String? {
        tips.count > 1 ? "\(currentIndex + 1)/\(tips.count)" : nil
    }
    var totalDuration: Int { currentTip.durationSeconds }
    var progressFraction: Double {
        let total = Double(totalDuration)
        guard total > 0 else { return 0 }
        return Double(secondsRemaining) / total
    }

    func complete() {
        onStep(currentTip, "completed")
        advance()
    }

    func requestSkip() {
        cancelTimers()
        showingSkipReason = true
    }

    func confirmSkip(reason: SkipReason) {
        onStep(currentTip, "skipped|\(reason.rawValue)")
        showingSkipReason = false
        advance()
    }

    func cancelSkip() {
        showingSkipReason = false
        if hasStarted { startCountdown() }
        startIdleWatchdog()
    }

    func startExercise() {
        hasStarted = true
        startCountdown()
    }

    func close() {
        onStep(currentTip, "skipped|closed")
        finish()
    }

    func appendSteps(_ newTips: [Tip]) {
        tips.append(contentsOf: newTips)
    }

    private func advance() {
        cancelTimers()
        if currentIndex + 1 < tips.count {
            currentIndex += 1
            secondsRemaining = currentTip.durationSeconds
            countdownDone = false
            hasStarted = false
            startIdleWatchdog()
        } else {
            finish()
        }
    }

    private func finish() {
        cancelTimers()
        onFinished()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
            } else {
                self.countdownDone = true
                self.countdownTimer?.invalidate()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    private func startIdleWatchdog() {
        idleTimer?.invalidate()
        let t = Timer(timeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.autoSkipFromTimeout()
        }
        RunLoop.main.add(t, forMode: .common)
        idleTimer = t
    }

    private func autoSkipFromTimeout() {
        onStep(currentTip, "skipped")
        finish()
    }

    func cancelTimers() {
        countdownTimer?.invalidate(); countdownTimer = nil
        idleTimer?.invalidate(); idleTimer = nil
    }
}

// MARK: - SwiftUI view

struct FloatingReminderView: View {
    @ObservedObject var vm: FloatingReminderViewModel

    private var cat: TipCategory { vm.currentTip.category }

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header

                Group {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs + 2) {
                            Text(vm.currentTip.name.resolve(vm.locale))
                                .font(DS.Font.title)
                            Text(vm.currentTip.instruction.resolve(vm.locale))
                                .font(DS.Font.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        countdownRing
                        benefitBox
                    }
                }
                .id(vm.currentIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: vm.currentIndex)

                Spacer(minLength: 0)
                actionRow
            }
            .padding(DS.Spacing.xl)
            .opacity(vm.showingSkipReason ? 0.2 : 1.0)
            .allowsHitTesting(!vm.showingSkipReason)

            if vm.showingSkipReason {
                skipReasonOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: 420, height: 540)
        .animation(.easeInOut(duration: 0.2), value: vm.showingSkipReason)
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Image(systemName: symbol(for: cat))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(categoryColor(cat))
                Text(categoryLabel(cat, locale: vm.locale))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                if let p = vm.progressLabel {
                    Text(p)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            Button(action: { vm.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(1.0, vm.progressFraction))))
                .stroke(
                    LinearGradient(
                        colors: [categoryColor(cat), categoryColor(cat).opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: vm.progressFraction)
            VStack(spacing: 2) {
                Text("\(vm.secondsRemaining)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(vm.locale == .zh ? "秒" : "sec")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140, height: 140)
        .frame(maxWidth: .infinity)
    }

    private var benefitBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(categoryColor(cat))
                .padding(.top, 2)
            Text(vm.currentTip.benefit.resolve(vm.locale))
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(categoryColor(cat).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionRow: some View {
        Group {
            if vm.hasStarted {
                HStack(spacing: DS.Spacing.sm + 2) {
                    Button(action: { vm.requestSkip() }) {
                        Text(vm.locale == .zh ? "跳过" : "Skip")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(PressableButtonStyle(
                        background: Color.primary.opacity(0.08),
                        tint: .primary,
                        cornerRadius: DS.Radius.sm + 2
                    ))

                    Button(action: { vm.complete() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text(vm.locale == .zh ? "做完了" : "Done")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(PressableButtonStyle(
                        background: Color.accentColor,
                        tint: .white,
                        cornerRadius: DS.Radius.sm + 2
                    ))
                    .shadow(color: Color.accentColor.opacity(vm.countdownDone ? 0.45 : 0.15), radius: vm.countdownDone ? 10 : 4)
                    .scaleEffect(vm.countdownDone ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: vm.countdownDone)
                }
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Button(action: { vm.startExercise() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text(vm.locale == .zh ? "开始" : "Start")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressableButtonStyle(
                        background: Color.accentColor,
                        tint: .white,
                        cornerRadius: DS.Radius.sm + 2
                    ))
                    Button(action: { vm.requestSkip() }) {
                        Text(vm.locale == .zh ? "跳过" : "Skip")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var skipReasonOverlay: some View {
        let reasons = FloatingReminderViewModel.SkipReason.allCases
        return VStack(spacing: DS.Spacing.md) {
            Text(vm.locale == .zh ? "为什么跳过？" : "Why skip?")
                .font(.system(size: 15, weight: .semibold))
            Text(vm.locale == .zh ? "告诉我一下，以后提醒会更贴心" : "Let me know — future reminders will adapt")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: DS.Spacing.sm) {
                ForEach(reasons) { r in
                    skipReasonButton(r)
                }
            }
            cancelSkipButton
                .padding(.top, DS.Spacing.xs)
        }
        .padding(DS.Spacing.xl)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20)
    }

    private func skipReasonButton(_ reason: FloatingReminderViewModel.SkipReason) -> some View {
        Button(action: { vm.confirmSkip(reason: reason) }) {
            Text(reason.label(vm.locale))
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(PressableButtonStyle(
            background: Color.primary.opacity(0.08),
            tint: .primary,
            cornerRadius: DS.Radius.sm + 2
        ))
    }

    private var cancelSkipButton: some View {
        Button(action: { vm.cancelSkip() }) {
            Text(vm.locale == .zh ? "取消" : "Cancel")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func symbol(for category: TipCategory) -> String {
        switch category {
        case .eye: return "eye.fill"
        case .neck: return "figure.cooldown"
        case .sedentary: return "figure.walk"
        case .noon: return "sun.max.fill"
        }
    }

    private func categoryColor(_ category: TipCategory) -> Color {
        switch category {
        case .eye: return .blue
        case .neck: return .purple
        case .sedentary: return .green
        case .noon: return .orange
        }
    }

    private func categoryLabel(_ category: TipCategory, locale: AppLocale) -> String {
        switch (category, locale) {
        case (.eye, .zh): return "护眼"
        case (.eye, .en): return "Eye care"
        case (.neck, .zh): return "颈肩"
        case (.neck, .en): return "Neck & shoulders"
        case (.sedentary, .zh): return "起身活动"
        case (.sedentary, .en): return "Move"
        case (.noon, .zh): return "午间户外"
        case (.noon, .en): return "Noon outdoor"
        }
    }
}

// MARK: - Blurred background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
