import UIKit
import Flutter
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    private func decodeBase64UrlSafe(_ value: String) -> String? {
        var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = normalized.count % 4
        if padding != 0 {
            normalized += String(repeating: "=", count: 4 - padding)
        }
        guard let data = Data(base64Encoded: normalized),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    private func keyFromDartDefines(named key: String) -> String? {
        guard let dartDefines = Bundle.main.object(forInfoDictionaryKey: "DART_DEFINES") as? String else {
            return nil
        }
        for entry in dartDefines.split(separator: ",") {
            guard let decoded = decodeBase64UrlSafe(String(entry)) else { continue }
            let prefix = "\(key)="
            if decoded.hasPrefix(prefix) {
                let value = String(decoded.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private func keyFromFirebasePlist() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let raw = dict["API_KEY"] as? String else {
            return nil
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func resolveGoogleMapsKey() -> String? {
        let candidateKeys = ["GOOGLE_MAPS_API_KEY", "GOOGLE_MAPS_API_KEY_IOS", "GMSApiKey"]
        for infoKey in candidateKeys {
            guard let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }
            // If build settings did not expand, plist contains literal $(VAR_NAME).
            if value.hasPrefix("$(") && value.hasSuffix(")") { continue }
            return value
        }

        // Fallback for builds that pass API keys only via --dart-define(-from-file).
        if let dartDefineKey = keyFromDartDefines(named: "GOOGLE_MAPS_API_KEY_IOS") {
            return dartDefineKey
        }
        if let dartDefineKey = keyFromDartDefines(named: "GOOGLE_MAPS_API_KEY") {
            return dartDefineKey
        }

        // Last fallback: Firebase API key from bundled GoogleService-Info.plist.
        return keyFromFirebasePlist()
    }

    override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if let mapsApiKey = resolveGoogleMapsKey() {
            GMSServices.provideAPIKey(mapsApiKey)
        } else {
            print("[Maps] Missing/invalid iOS API key. Check GOOGLE_MAPS_API_KEY_IOS in build settings.")
        }

        GeneratedPluginRegistrant.register(with: self)

        // Set notification delegate AFTER plugin registration so we are
        // the UNUserNotificationCenter delegate and can control foreground display.
        if #available (iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ──────────────────────────────────────────────────────────────
    // Foreground notification presentation
    //
    // iOS calls this delegate before displaying a notification when
    // the app is in the FOREGROUND.
    //
    // Strategy:
    //   • Notifications created by AwesomeNotifications carry the
    //     identifier prefix "awesome_" — let them show (they already
    //     have correct sound/badge/alert configured by the plugin).
    //   • Raw FCM/APNs notifications (no "awesome_" prefix) are
    //     suppressed here because our Dart _handleForeground() shows
    //     an in-app overlay instead.  Allowing both would result in a
    //     duplicate: one system banner + one in-app overlay.
    //
    // For BACKGROUND / KILLED state APNs shows the notification
    // automatically before any Dart code runs; that is handled by the
    // NotificationService Extension (ios/NotificationService/).
    // ──────────────────────────────────────────────────────────────

    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier

        // AwesomeNotifications uses a numeric string ID (e.g. "12345").
        // FCM auto-generated identifiers follow the pattern "FCM_<uuid>".
        // We allow AwesomeNotifications-created ones through so the user
        // sees the notification banner when the app is open and our Dart
        // code chose to create a system notification (e.g. background state
        // just resumed).
        let isAwesomeNotification = !identifier.hasPrefix("FCM_") && !identifier.hasPrefix("com.google")

        if isAwesomeNotification {
            // Show banner + play sound + update badge — exactly what the user
            // configured via the AwesomeNotifications channel settings.
            if #available (iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge, .list])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        } else {
            // Suppress raw FCM banner — our Dart foreground handler shows
            // an in-app overlay for service/emergency requests, and calls
            // AwesomeNotifications().createNotification() for other types,
            // which will then trigger this delegate again with an
            // AwesomeNotifications identifier.
            completionHandler([])
        }
    }
}