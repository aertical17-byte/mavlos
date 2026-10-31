import SwiftUI
import AppKit
import UserNotifications
import MavlosCore

@main
struct MavlosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("mavlos") {
            MainView()
                .environmentObject(state)
                .task { await state.bootstrap() }
                .onReceive(
                    NotificationCenter.default
                        .publisher(for: NSApplication.didBecomeActiveNotification)
                ) { _ in
                    Task { await state.checkScheduledScan() }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 732)
    }
}

/// Configura l'app al lancio: aspetto scuro coerente, presentazione banner
/// anche a finestra attiva, terminazione automatica alla chiusura.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
