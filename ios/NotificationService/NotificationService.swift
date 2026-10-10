import UserNotifications

// ─────────────────────────────────────────────────────────────────────────────
// Notification Service Extension
//
// PURPOSE
//   When the app is in BACKGROUND or KILLED state, iOS auto-displays the APNs
//   notification before any app code runs.  Because our Dart background handler
//   (firebaseMessagingBackgroundHandler) already creates an AwesomeNotification
//   with ACCEPT / REJECT buttons, the raw APNs alert would create a DUPLICATE.
//
//   This extension intercepts the APNs notification and clears its visible
//   content so iOS shows nothing.  The Dart handler then shows exactly one
//   AwesomeNotification.
//
// SERVER-SIDE REQUIREMENT
//   This extension only runs for messages that have  mutable_content: true
//   in the FCM payload (maps to  apns-mutable-content: 1  in APNs headers).
//
//   Add the following to every FCM message sent to iOS:
//
//     Firebase Admin SDK (Node.js / Python / etc.):
//       apns: {
//         headers: { 'apns-push-type': 'alert', 'apns-priority': '10' },
//         payload: { aps: { 'mutable-content': 1, 'content-available': 1 } }
//       }
//
//     FCM HTTP v1 REST:
//       "apns": {
//         "headers": { "apns-priority": "10" },
//         "payload": { "aps": { "mutable-content": 1, "content-available": 1 } }
//       }
//
// HOW TO ADD THIS EXTENSION TO XCODE
//   1. Open ios/Runner.xcworkspace in Xcode.
//   2. File ▸ New ▸ Target → "Notification Service Extension" → name it
//      "NotificationService" → Finish.
//   3. Replace the generated NotificationService.swift with THIS file
//      (or let Xcode keep its own copy — the logic is identical).
//   4. Set the extension's Deployment Target to iOS 10.0+.
//   5. In the extension's  Build Settings ▸ iOS Deployment Target  make sure
//      it is ≤ your app's deployment target.
//   6. In Runner ▸ Signing & Capabilities ensure Push Notifications capability
//      is enabled (it should already be for the main Runner target).
//   7. Build & run — the extension is bundled automatically.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo

        // Detect our app's FCM data notifications by their "type" key.
        // These are fully handled by the Dart background handler which
        // creates an AwesomeNotification — suppress the raw APNs alert.
        let isOurFCMMessage = userInfo["type"] != nil || userInfo["gcm.message_id"] != nil

        if isOurFCMMessage {
            // Clear all visible content so iOS shows nothing.
            // The Dart background handler will display the proper
            // AwesomeNotification with ACCEPT / REJECT action buttons.
            bestAttemptContent.title    = ""
            bestAttemptContent.subtitle = ""
            bestAttemptContent.body     = ""
            bestAttemptContent.badge    = nil
            bestAttemptContent.sound    = nil
        }

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension is terminated by iOS.
        // Deliver whatever content we have (even if incomplete).
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

