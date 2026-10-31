import Foundation
import UserNotifications

/// Notifiche locali di macOS, solo su completamento scansione e solo con
/// il consenso dell'utente.
public enum NotificationService {

    public static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// Notifica di completamento scansione. Non avvia mai spostamenti:
    /// prepara solo l'esito e richiede l'approvazione dell'utente in app.
    public static func notifyScanCompleted(count: Int, folderName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Scansione completata"
        content.body = "\(Formatting.fileCount(count)) file pronti da sistemare in \(folderName)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "mavlos.scan.complete.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
