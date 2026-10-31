import Foundation
import Combine

/// Frequenza della scansione automatica. La scansione pianificata prepara
/// solamente i risultati: non sposta mai file senza approvazione esplicita.
public enum AutoScanFrequency: String, Codable, CaseIterable, Sendable, Equatable {
    case off
    case daily
    case weekly
    case monthly

    public var displayName: String {
        switch self {
        case .off: return "Disattivata"
        case .daily: return "Ogni giorno"
        case .weekly: return "Ogni settimana"
        case .monthly: return "Ogni mese"
        }
    }

    public var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .daily: return 86_400
        case .weekly: return 7 * 86_400
        case .monthly: return 30 * 86_400
        }
    }
}

/// Cartella usata di recente (persistita per le ultime selezioni).
public struct RecentFolder: Codable, Equatable, Hashable, Sendable {
    public var path: String
    public var displayName: String
    public var securityScoped: Bool
    public var addedAt: Date

    public init(path: String, displayName: String, securityScoped: Bool, addedAt: Date = Date()) {
        self.path = path
        self.displayName = displayName
        self.securityScoped = securityScoped
        self.addedAt = addedAt
    }
}

/// Preferenze persistenti di Mavlos.
public struct Preferences: Codable, Equatable, Sendable {
    public var defaultFolderPath: String?
    public var defaultFolderDisplayName: String?
    public var defaultFolderIsSecurityScoped: Bool
    public var recursiveScanning: Bool
    public var automaticScan: AutoScanFrequency
    public var askBeforeMoving: Bool
    public var duplicatePolicy: ConflictPolicy
    public var notifyOnScanComplete: Bool
    public var customRules: [OrganizationRule]
    /// Override della destinazione per le regole di sistema (chiave: raw della categoria).
    public var destinationOverrides: [String: String]
    public var lastAutomaticScan: Date?
    /// Percorsi selezionati nell'ultima finestra di selezione.
    public var lastSelectionPaths: [String]

    public init() {
        self.defaultFolderPath = nil
        self.defaultFolderDisplayName = nil
        self.defaultFolderIsSecurityScoped = false
        self.recursiveScanning = true
        self.automaticScan = .weekly
        self.askBeforeMoving = true
        self.duplicatePolicy = .keepBoth
        self.notifyOnScanComplete = true
        self.customRules = []
        self.destinationOverrides = [:]
        self.lastAutomaticScan = nil
        self.lastSelectionPaths = []
    }

    private enum CodingKeys: String, CodingKey {
        case defaultFolderPath = "defaultFolder.path"
        case defaultFolderDisplayName = "defaultFolder.name"
        case defaultFolderIsSecurityScoped
        case recursiveScanning
        case automaticScan
        case askBeforeMoving
        case duplicatePolicy
        case notifyOnScanComplete
        case customRules
        case destinationOverrides
        case lastAutomaticScan
        case lastSelectionPaths
    }
}

/// Archivio centralizzato delle preferenze, osservabile dall'interfaccia
/// e leggibile dai servizi (scansione, classificazione, organizzazione).
public final class SettingsStore: ObservableObject, @unchecked Sendable {

    @Published public private(set) var preferences: Preferences

    private let defaults: UserDefaults
    private static let preferencesKey = "mavlos.preferences"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferences = Self.load(from: defaults)
    }

    // MARK: - Mutazione

    public func update(_ mutation: (inout Preferences) -> Void) {
        var copy = preferences
        mutation(&copy)
        preferences = copy
        persist(copy)
    }

    // MARK: - Letture di comodo

    /// Cartella predefinita come riferimento, se ancora esistente.
    public func defaultFolderRef() -> FolderRef? {
        guard let path = preferences.defaultFolderPath else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard PermissionManager.accessibility(of: url) != .missing else { return nil }
        return FolderRef(
            url: url,
            displayName: preferences.defaultFolderDisplayName ?? url.lastPathComponent,
            securityScoped: preferences.defaultFolderIsSecurityScoped
        )
    }

    /// Override di destinazione per una regola di sistema.
    public func destinationOverride(for category: FileCategory) -> URL? {
        preferences.destinationOverrides[category.rawValue].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Libro di regole formato dalle preferenze correnti.
    public func effectiveRuleBook() -> RuleBook {
        var overrides: [FileCategory: URL] = [:]
        for (raw, value) in preferences.destinationOverrides {
            if let category = FileCategory(rawValue: raw) {
                overrides[category] = URL(fileURLWithPath: value, isDirectory: true)
            }
        }
        return RuleBook(customRules: preferences.customRules, systemOverrides: overrides)
    }

    /// True se è il momento di eseguire la scansione pianificata.
    public func isAutomaticScanDue(now: Date = Date()) -> Bool {
        guard preferences.automaticScan != .off,
              let interval = preferences.automaticScan.interval
        else { return false }
        guard let last = preferences.lastAutomaticScan else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    // MARK: - Persistenza

    private static func load(from defaults: UserDefaults) -> Preferences {
        guard let data = defaults.data(forKey: preferencesKey),
              let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }
        return decoded
    }

    private func persist(_ prefs: Preferences) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(prefs) else { return }
        defaults.set(data, forKey: Self.preferencesKey)
    }
}
