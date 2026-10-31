import Foundation
import UserNotifications

public extension Notification.Name {
    /// Posted when the user clicks the "update available" notification.
    static let avdStudioShowUpdates = Notification.Name("dev.marcos.avdstudio.showUpdates")
}

/// Posts a native macOS notification. Needs a real app bundle, so it is only created by the app itself
/// (never by tests, where `UNUserNotificationCenter.current()` would crash).
public final class SystemUpdateNotifier: NSObject, UpdateNotifier, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public override init() {
        center = UNUserNotificationCenter.current()
        super.init()
        center.delegate = self
    }

    public func notifyUpdateAvailable(current: AppVersion, latest: AppVersion) async {
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let content = UNMutableNotificationContent()
        content.title = "AVD Studio \(latest) is available"
        content.body = "You have \(current). Open AVD Studio to see what's new and download it."
        content.sound = .default
        content.userInfo = ["action": "showUpdates"]
        let request = UNNotificationRequest(identifier: "dev.marcos.avdstudio.update.\(latest)", content: content, trigger: nil)
        try? await center.add(request)
    }

    // Show the banner even while the app is frontmost.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["action"] as? String == "showUpdates" else { return }
        await MainActor.run { NotificationCenter.default.post(name: .avdStudioShowUpdates, object: nil) }
    }
}
