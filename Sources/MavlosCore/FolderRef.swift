import Foundation

/// Cartella di riferimento usata per scansioni, impostazioni e selezioni.
public struct FolderRef: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let url: URL
    /// Nome esposto all'utente (es. "Download", "Scrivania", "Documenti").
    public let displayName: String
    /// URL del percorso in cui è stato rilasciato l'accesso tramite selettore nativo.
    public let securityScoped: Bool

    public init(url: URL, displayName: String, securityScoped: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.securityScoped = securityScoped
    }

    public var path: String { url.path }
}
