import Foundation

/// Categorie di file riconosciute da Mavlos.
///
/// L'enumerazione è l'unica fonte di verità per estensioni note e
/// destinazione predefinita di ciascuna categoria. Per aggiungere una nuova
/// categoria basta aggiungere un case e le sue estensioni.
public enum FileCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case images
    case documents
    case music
    case video
    case archives
    case others

    // MARK: - Costruzione

    /// Restituisce la categoria associata a un'estensione (senza punto, case-insensitive).
    public init?(fileExtension ext: String) {
        let normalized = Self.normalized(ext)
        guard !normalized.isEmpty,
              let match = Self.allCases.first(where: { $0.knownExtensions.contains(normalized) })
        else { return nil }
        self = match
    }

    /// Normalizza un'estensione rimuovendo il punto iniziale e la spaziatura.
    public static func normalized(_ ext: String) -> String {
        ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    }

    // MARK: - Etichette

    /// Nome completo della categoria (usato in Impostazioni e revisione).
    public var displayName: String {
        switch self {
        case .images: return "Immagini"
        case .documents: return "Documenti"
        case .music: return "Musica"
        case .video: return "Video"
        case .archives: return "Archivi"
        case .others: return "Altri file"
        }
    }

    /// Etichetta breve usata nel riepilogo dei risultati (es. "Lavoro").
    public var shortLabel: String {
        switch self {
        case .documents: return "Lavoro"
        default: return displayName
        }
    }

    // MARK: - Estensioni note (PRD + sovrainsieme curato)

    public var knownExtensions: [String] {
        switch self {
        case .images:
            return ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tiff", "tif", "bmp",
                    "svg", "raw", "arw", "cr2", "nef", "dng", "rw2", "orf", "avif"]
        case .documents:
            return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv",
                    "md", "markdown", "pages", "numbers", "key", "odt", "ods", "odp", "epub",
                    "html", "htm", "eml", "json", "xml", "ics"]
        case .music:
            return ["mp3", "wav", "flac", "aac", "m4a", "aiff", "aif", "ogg", "opus", "wma", "mid"]
        case .video:
            return ["mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "mpg", "mpeg", "3gp", "mts"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "dmg", "pkg"]
        case .others:
            return []
        }
    }

    /// Estensione più rappresentativa della categoria (per icone e descrizioni).
    public var representativeExtensions: [String] {
        switch self {
        case .images: return ["jpg", "png", "heic"]
        case .documents: return ["pdf", "docx", "xlsx", "pptx"]
        case .music: return ["mp3", "m4a", "flac"]
        case .video: return ["mp4", "mov", "mkv"]
        case .archives: return ["zip", "7z", "tar"]
        case .others: return ["dat"]
        }
    }

    // MARK: - Destinazione predefinita

    /// Restituisce la destinazione predefinita della categoria, risolvendo le
    /// cartelle di sistema dell'utente (le macro-familie supportate da macOS,
    /// es. ~/Pictures visualizzata come ~/Immagini nei sistemi italiani).
    public func defaultDestinationURL(home: URL? = nil) -> URL? {
        switch self {
        case .images:
            return Self.systemURL(.picturesDirectory)
        case .documents:
            return Self.systemURL(.documentDirectory)?.appendingPathComponent("Lavoro", isDirectory: true)
        case .music:
            return Self.systemURL(.musicDirectory)
        case .video:
            return Self.systemURL(.moviesDirectory)
        case .archives:
            return Self.systemURL(.documentDirectory)?.appendingPathComponent("Archivi", isDirectory: true)
        case .others:
            return nil
        }
    }

    /// Risolve una cartella standard nel dominio utente, se disponibile.
    public static func systemURL(_ directory: FileManager.SearchPathDirectory) -> URL? {
        FileManager.default.urls(for: directory, in: .userDomainMask).first
    }
}
