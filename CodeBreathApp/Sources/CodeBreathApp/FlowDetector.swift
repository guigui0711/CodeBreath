// Flow detector: signals that suggest deferring a reminder to protect the user's focus.
//
// Keystroke rate uses NSEvent.addGlobalMonitorForEvents which requires Accessibility
// permission. Without permission, the keystroke check silently returns 0 (non-blocking).
// Fullscreen / screen-sharing checks work without permission.

import AppKit
import Foundation

final class FlowDetector {
    private var keystrokeTimes: [Date] = []
    private let keystrokeWindow: TimeInterval = 60
    private let keystrokeThreshold = 80
    private var keyMonitor: Any?

    init() {
        startKeystrokeMonitor()
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    /// nil = fire now. Otherwise = recommended defer in seconds.
    func shouldDeferReminder() -> TimeInterval? {
        if isScreenSharingActive() { return 600 }   // 10 min
        if isFullscreenFrontmost()  { return 300 }  // 5 min
        if recentKeystrokeRate()  > keystrokeThreshold { return 180 }  // 3 min
        return nil
    }

    // MARK: - Signals

    private func isScreenSharingActive() -> Bool {
        // Heuristic: look for common screen-share / meeting apps in the running app list.
        // (CGDisplayIsCaptured was deprecated; proper detection requires private APIs.)
        let bundleIds: Set<String> = [
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.microsoft.teams",
            "com.apple.ScreenSharing",
            "com.cisco.webexmeetingsapp",
            "com.logmein.GoToMeeting",
        ]
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier, bundleIds.contains(id), app.isActive {
                return true
            }
        }
        return false
    }

    private func isFullscreenFrontmost() -> Bool {
        guard let mainScreen = NSScreen.main else { return false }
        let frame = mainScreen.frame
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        if front.bundleIdentifier == Bundle.main.bundleIdentifier { return false }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == front.processIdentifier,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            if abs(bounds.width - frame.width) < 2 && abs(bounds.height - frame.height) < 2 {
                return true
            }
            break
        }
        return false
    }

    private func startKeystrokeMonitor() {
        // Requires Accessibility permission. If not granted, handler silently never fires.
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.keystrokeTimes.append(Date())
        }
    }

    private func recentKeystrokeRate() -> Int {
        let cutoff = Date().addingTimeInterval(-keystrokeWindow)
        keystrokeTimes.removeAll(where: { $0 < cutoff })
        return keystrokeTimes.count
    }
}
