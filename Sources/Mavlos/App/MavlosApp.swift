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

/// Esecuzione CLI per verifiche automatizzate (`--selftest-organize <cartella>`):
/// scansione → classificazione → spostamento REALE con destinazioni interne
/// alla cartella di test (`<cartella>/Organizzati/<Categoria>`), journal in un
/// file temporaneo. Stampa gli esiti su stdout ed esce: non fa parte del
/// flusso grafico e non tocca mai le cartelle reali dell'utente.
enum SelftestOrganize {

    @MainActor
    static func run(folder: URL) async {
        let tagName = "MAVLOS-SELFTEST"
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else {
            FileHandle.standardError.write("\(tagName) cartella inesistente: \(folder.path)\n".data(using: .utf8)!)
            exit(4)
        }

        let scan = await FileScanner.scan(
            folders: [FolderRef(url: folder, displayName: folder.lastPathComponent)],
            recursive: true,
            ruleBook: RuleBook()
        )

        let organized = folder.appendingPathComponent("Organizzati", isDirectory: true)
        var items = scan.files
        for index in items.indices where items[index].status == .classified {
            items[index].destinationURL = organized
                .appendingPathComponent(items[index].category.displayName, isDirectory: true)
        }

        let proposals = FileOrganizer.proposals(for: items, policy: .keepBoth)
        let journalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mavlos-selftest-journal.json")
        let run = await OrganizationService.organize(
            proposals: proposals,
            journal: OperationJournal(storeURL: journalURL)
        )

        print("\(tagName) analyzed=\(scan.files.count) selected=\(proposals.count) moved=\(run.movedCount) skipped=\(run.skippedCount) failed=\(run.failedCount)")
        for result in run.results {
            let detail = result.finalURL?.path ?? result.message ?? ""
            print("\(tagName) \(result.outcome.rawValue) \(result.fileName) \(detail)")
        }
        exit(run.movedCount > 0 && run.failedCount == 0 ? 0 : 2)
    }
}

/// Configura l'app al lancio: aspetto scuro coerente, presentazione banner
/// anche a finestra attiva, terminazione automatica alla chiusura.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Modalità verifica headless: `--selftest-organize <cartella>`.
        let arguments = CommandLine.arguments
        if let flagIndex = arguments.firstIndex(of: "--selftest-organize"),
           flagIndex + 1 < arguments.count {
            let folder = URL(fileURLWithPath: arguments[flagIndex + 1], isDirectory: true)
            Task { await SelftestOrganize.run(folder: folder) }
            return
        }

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
