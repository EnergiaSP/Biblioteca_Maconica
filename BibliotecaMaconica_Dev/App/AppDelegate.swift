import UIKit
import UserNotifications
import Combine

@MainActor
final class NotificationReadingRouter: ObservableObject {
    static let shared = NotificationReadingRouter()
    @Published private(set) var pendingURL: URL?

    func receive(_ url: URL) {
        guard url.scheme == "breviario", url.host == "leitura" else { return }
        pendingURL = url
    }

    func consume(_ url: URL) {
        if pendingURL == url { pendingURL = nil }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let urlString = response.notification.request.content.userInfo["url"] as? String
        let url = urlString.flatMap(URL.init(string:))
        DispatchQueue.main.async {
            if let url {
                // Keep cold-start navigation until the SwiftUI reader is subscribed.
                NotificationReadingRouter.shared.receive(url)
            }
            // UIKit restores the notification scene when this callback completes.
            completionHandler()
        }
    }
}
