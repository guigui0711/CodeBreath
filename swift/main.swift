// CodeBreathNotify — lightweight macOS notification helper for CodeBreath.
//
// Posts alert-style notifications via UNUserNotificationCenter with
// "Done" / "Skip" action buttons.  Writes the user's response to a
// temp file so the calling Python process can read it.
//
// Usage (must be launched as .app bundle via open):
//   open -W -n CodeBreathNotify.app --args \
//     --title "..." --subtitle "..." --body "..." \
//     --done-label "Done" --skip-label "Skip" \
//     --response-file /tmp/codebreath_response_XXXX.json \
//     --sound default --timeout 300
//
// Response file JSON:  {"action": "done"|"skip"|"dismissed"|"timeout"}

import AppKit
import UserNotifications

// MARK: - Argument parsing (zero dependencies)

func arg(_ key: String) -> String? {
    let args = CommandLine.arguments
    guard let idx = args.firstIndex(of: key), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

let ntitle       = arg("--title")        ?? "CodeBreath"
let nsubtitle    = arg("--subtitle")     ?? ""
let nbody        = arg("--body")         ?? ""
let doneLabel    = arg("--done-label")   ?? "Done"
let skipLabel    = arg("--skip-label")   ?? "Skip"
let responseFile = arg("--response-file") ?? ""
let soundName    = arg("--sound")        ?? "default"
let timeoutSec   = Double(arg("--timeout") ?? "300") ?? 300

// MARK: - Constants

let categoryID   = "com.codebreath.health"
let doneActionID = "DONE_ACTION"
let skipActionID = "SKIP_ACTION"
let notifID      = "codebreath-\(ProcessInfo.processInfo.globallyUniqueString)"

// MARK: - Response writer

func writeResponse(_ action: String) {
    if !responseFile.isEmpty {
        let json = "{\"action\": \"\(action)\"}\n"
        try? json.write(toFile: responseFile, atomically: true, encoding: .utf8)
    }
    fputs("action=\(action)\n", stdout)
    fflush(stdout)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate with notification handling

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register category with action buttons
        let doneAction = UNNotificationAction(
            identifier: doneActionID,
            title: doneLabel,
            options: []
        )
        let skipAction = UNNotificationAction(
            identifier: skipActionID,
            title: skipLabel,
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [doneAction, skipAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        center.setNotificationCategories([category])

        // Request authorization, then send notification
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    fputs("Auth error: \(error.localizedDescription)\n", stderr)
                }
                if !granted {
                    fputs("Notifications not permitted. Enable in System Settings > Notifications > CodeBreath.\n", stderr)
                    // Still try to send — sometimes works even without explicit grant
                }
                self.sendNotification()
            }
        }

        // Timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSec) {
            center.removeDeliveredNotifications(withIdentifiers: [notifID])
            writeResponse("timeout")
        }
    }

    func sendNotification() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = ntitle
        content.subtitle = nsubtitle
        content.body = nbody
        content.categoryIdentifier = categoryID

        if soundName == "default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        }

        let request = UNNotificationRequest(
            identifier: notifID,
            content: content,
            trigger: nil  // deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                fputs("Send error: \(error.localizedDescription)\n", stderr)
                writeResponse("error")
            }
        }
    }

    // Show notification even when our app has focus
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    // User interacted with the notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case doneActionID:
            writeResponse("done")
        case skipActionID:
            writeResponse("skip")
        case UNNotificationDismissActionIdentifier:
            writeResponse("dismissed")
        default:
            // Clicked notification body → start exercise
            writeResponse("done")
        }
        completionHandler()
    }
}

// MARK: - Main entry

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no dock icon, no menu bar

let appDelegate = AppDelegate()
app.delegate = appDelegate

withExtendedLifetime(appDelegate) {
    app.run()
}
