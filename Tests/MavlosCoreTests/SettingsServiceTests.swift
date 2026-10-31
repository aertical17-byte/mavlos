import Testing
import Foundation
import MavlosCore

@Suite
final class SettingsServiceTests {

    private var suiteName: String
    private var defaults: UserDefaults

    init() {
        suiteName = "mavlos-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Predefiniti

    @Test func defaultPreferencesMatchPRD() {
        let store = SettingsStore(defaults: defaults)
        let prefs = store.preferences

        #expect(prefs.recursiveScanning == true)
        #expect(prefs.automaticScan == .weekly)
        #expect(prefs.askBeforeMoving == true)
        #expect(prefs.duplicatePolicy == .keepBoth)
        #expect(prefs.notifyOnScanComplete == true)
        #expect(prefs.defaultFolderPath == nil)
        #expect(prefs.customRules.isEmpty == true)
        #expect(prefs.lastSelectionPaths.isEmpty == true)
        #expect(prefs.lastAutomaticScan == nil)
    }

    // MARK: Persistenza

    @Test func preferencesPersistAcrossStores() {
        let first = SettingsStore(defaults: defaults)
        let target = TestPaths.tempRoot().appendingPathComponent("Regole/Prova")
        first.update { prefs in
            prefs.recursiveScanning = false
            prefs.automaticScan = .daily
            prefs.askBeforeMoving = false
            prefs.duplicatePolicy = .skip
            prefs.notifyOnScanComplete = false
            prefs.defaultFolderPath = "/utente/prova/Download"
            prefs.defaultFolderDisplayName = "Download"
            prefs.lastSelectionPaths = ["/utente/prova/Download", "/utente/prova/Scrivania"]
            prefs.destinationOverrides = [FileCategory.images.rawValue: target.path]
        }

        let second = SettingsStore(defaults: defaults)
        let loaded = second.preferences

        #expect(loaded.recursiveScanning == false)
        #expect(loaded.automaticScan == .daily)
        #expect(loaded.askBeforeMoving == false)
        #expect(loaded.duplicatePolicy == .skip)
        #expect(loaded.notifyOnScanComplete == false)
        #expect(loaded.defaultFolderPath == "/utente/prova/Download")
        #expect(loaded.defaultFolderDisplayName == "Download")
        #expect(loaded.lastSelectionPaths.count == 2)
        #expect(loaded.destinationOverrides[FileCategory.images.rawValue] == target.path)
    }

    @Test func defaultFolderRefSurvivesOnlyExistingPaths() {
        let store = SettingsStore(defaults: defaults)
        let realFolder = TestPaths.tempRoot()

        store.update { prefs in
            prefs.defaultFolderPath = realFolder.path
            prefs.defaultFolderDisplayName = "Prova"
        }
        #expect(store.defaultFolderRef()?.displayName == "Prova")

        store.update { prefs in
            prefs.defaultFolderPath = "/mancante/completamente"
        }
        #expect(store.defaultFolderRef() == nil, "una cartella inesistente non diventa riferimento")
    }

    @Test func destinationOverrideReadableByCategory() {
        let store = SettingsStore(defaults: defaults)
        let target = TestPaths.tempRoot().appendingPathComponent("MieFoto")

        store.update { prefs in
            prefs.destinationOverrides = [FileCategory.images.rawValue: target.path]
        }

        #expect(store.destinationOverride(for: .images)?.path == target.path)
        #expect(store.destinationOverride(for: .music) == nil)
    }

    // MARK: Regole

    @Test func effectiveRuleBookCombinesCustomRulesAndOverrides() {
        let store = SettingsStore(defaults: defaults)
        let destination = TestPaths.tempRoot().appendingPathComponent("Volti")
        store.update { prefs in
            prefs.customRules = [OrganizationRule(
                name: "Volti",
                extensions: Set(["jfif", ".WEBP"]),
                destination: destination,
                category: .images,
                priority: 7,
                isActive: true
            )]
        }

        let ruleBook = store.effectiveRuleBook()
        let classification = ruleBook.classify(name: "volto.jfif", fileExtension: "jfif")
        #expect(classification.destination == destination)
        #expect(classification.ruleName == "Volti")

        // Le regole di sistema restano generabili separatamente.
        let systemRules = OrganizationRule.systemRules()
        #expect(systemRules.contains { $0.name == "Immagini" })
        #expect(systemRules.allSatisfy { $0.isSystem == true })
    }

    @Test func ruleMatchingNormalizesExtensions() {
        let destination = TestPaths.tempRoot().appendingPathComponent("X")
        let rule = OrganizationRule(name: "R", extensions: Set(["JsOn"]), destination: destination,
                                    category: .documents, priority: 1, isActive: true, isSystem: false)
        #expect(rule.matches(fileExtension: "json"))
        #expect(rule.matches(fileExtension: ".JSON"))
        #expect(rule.matches(fileExtension: "xml") == false)
        #expect(rule.extensions == ["json"])
    }

    // MARK: Scansione pianificata

    @Test func automaticScanDueWhenNeverPerformed() {
        let store = SettingsStore(defaults: defaults)
        store.update { _ in } // predefiniti: weekly
        #expect(store.isAutomaticScanDue() == true)
    }

    @Test func automaticScanNotDueAfterRecentScan() {
        let store = SettingsStore(defaults: defaults)
        store.update { prefs in
            prefs.lastAutomaticScan = Date().addingTimeInterval(-3600) // 1 h fa
        }
        #expect(store.isAutomaticScanDue() == false)
    }

    @Test func automaticScanDueWhenIntervalElapsed() {
        let store = SettingsStore(defaults: defaults)
        store.update { prefs in
            prefs.lastAutomaticScan = Date().addingTimeInterval(-(7 * 86_400 + 60)) // più di una settimana
        }
        #expect(store.isAutomaticScanDue() == true)
    }

    @Test func automaticScanOffNeverDue() {
        let store = SettingsStore(defaults: defaults)
        store.update { prefs in
            prefs.automaticScan = .off
            prefs.lastAutomaticScan = nil
        }
        #expect(store.isAutomaticScanDue() == false)
    }

    @Test func autoScanFrequenciesProvideIntervals() {
        #expect(AutoScanFrequency.off.interval == nil)
        #expect(AutoScanFrequency.daily.interval == 86_400)
        #expect(AutoScanFrequency.weekly.interval == 7 * 86_400)
        #expect(AutoScanFrequency.monthly.interval == 30 * 86_400)
    }
}
