import Foundation

/// Regola di classificazione personalizzata.
///
/// Le regole predefinite di sistema derivano da `FileCategory` e non vengono
/// eliminate o modificate in struttura: la loro destinazione è sovrascrivibile
/// tramite overrides (vedi `RuleBook`), quelle personalizzate hanno priorità.
public struct OrganizationRule: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// Estensioni interessate, senza punto e in minuscolo.
    public var extensions: Set<String>
    /// Cartella di destinazione.
    public var destination: URL
    /// Categoria assegnata ai file corrispondenti.
    public var category: FileCategory
    /// Priorità: valore maggiore vince in caso di più regole corrispondenti.
    public var priority: Int
    public var isActive: Bool
    public let isSystem: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        extensions: Set<String>,
        destination: URL,
        category: FileCategory,
        priority: Int,
        isActive: Bool,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.extensions = Self.normalize(Array(extensions))
        self.destination = destination
        self.category = category
        self.priority = priority
        self.isActive = isActive
        self.isSystem = isSystem
    }

    public static func normalize(_ exts: [String]) -> Set<String> {
        Set(exts
            .map { FileCategory.normalized($0) }
            .filter { !$0.isEmpty })
    }

    /// Verifica se la regola interessa il file (per estensione).
    public func matches(fileExtension ext: String) -> Bool {
        extensions.contains(FileCategory.normalized(ext))
    }

    /// Regole di sistema generate dalle categorie predefinite.
    public static func systemRules(destinationOverrides: [FileCategory: URL] = [:]) -> [OrganizationRule] {
        FileCategory.allCases.compactMap { category in
            guard category != .others else { return nil }
            let destination = destinationOverrides[category] ?? category.defaultDestinationURL()
            guard let destination else { return nil }
            return OrganizationRule(
                name: category.displayName,
                extensions: Set(category.knownExtensions),
                destination: destination,
                category: category,
                priority: 0,
                isActive: true,
                isSystem: true
            )
        }
    }
}
