import Foundation

/// Stato della classificazione di un file.
public enum ClassificationStatus: String, Codable, Sendable, Hashable {
    /// Categoria e destinazione determinate in modo affidabile.
    case classified
    /// Nessuna destinazione affidabile: richiede una decisione dell'utente.
    case needsReview
}

/// Un file rilevato durante una scansione, con la classificazione corrente.
public struct FileItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let url: URL
    public let pathExtension: String
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?

    /// Categoria assegnata (modificabile in revisione).
    public var category: FileCategory
    /// Destinazione proposta; `nil` per i file da verificare ("Altri file").
    public var destinationURL: URL?
    /// Origine della classificazione ("regola personale", "estensione", "tipo di file", "da verificare").
    public var ruleName: String?
    public var status: ClassificationStatus
    /// Suggerimento informativo mostrato all'utente, senza effetti sullo spostamento.
    public var hint: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        pathExtension: String,
        size: Int64,
        creationDate: Date?,
        modificationDate: Date?,
        category: FileCategory,
        destinationURL: URL?,
        ruleName: String?,
        status: ClassificationStatus,
        hint: String? = nil
    ) {
        self.id = id
        self.url = url
        self.pathExtension = pathExtension
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.category = category
        self.destinationURL = destinationURL
        self.ruleName = ruleName
        self.status = status
        self.hint = hint
    }

    // MARK: - Computed

    public var displayName: String { url.lastPathComponent }
    /// Cartella di origine del file.
    public var originalFolder: URL { url.deletingLastPathComponent() }
    /// Nome base senza estensione.
    public var baseName: String { url.deletingPathExtension().lastPathComponent }
}
