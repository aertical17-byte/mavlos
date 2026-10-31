import Foundation

// MARK: - Fasi

public enum ScanPhase: String, Codable, Sendable {
    case waiting
    case scanning
    case completed
    case cancelled
    case failed
}

/// Istantanea di avanzamento emessa dalla scansione.
public struct ScanProgressSnapshot: Equatable, Sendable {
    public var phase: ScanPhase
    public var found: Int
    public var analyzed: Int
    public var classified: Int
    public var currentFolder: String?

    public init(phase: ScanPhase, found: Int = 0, analyzed: Int = 0, classified: Int = 0, currentFolder: String? = nil) {
        self.phase = phase
        self.found = found
        self.analyzed = analyzed
        self.classified = classified
        self.currentFolder = currentFolder
    }

    public static let initial = ScanProgressSnapshot(phase: .waiting)
}

// MARK: - Statistiche

public struct ScanStatistics: Codable, Sendable, Equatable {
    /// File candidati letti dal filesystem.
    public var analyzedCount: Int
    /// File con classificazione affidabile.
    public var classifiedCount: Int
    /// Elementi ignorati per sicurezza (pacchetti, link simbolici, cartelle protette).
    public var skippedCount: Int
    /// Elementi non leggibili per permessi o errori.
    public var errorCount: Int

    public init(analyzedCount: Int = 0, classifiedCount: Int = 0, skippedCount: Int = 0, errorCount: Int = 0) {
        self.analyzedCount = analyzedCount
        self.classifiedCount = classifiedCount
        self.skippedCount = skippedCount
        self.errorCount = errorCount
    }
}

// MARK: - Statistiche per categoria

public struct CategoryStats: Identifiable, Hashable, Sendable {
    public let category: FileCategory
    public let count: Int
    public let size: Int64
    /// Destinazione proposta per l'intera categoria al momento della scansione.
    public let destination: URL?
    public var id: FileCategory { category }

    public init(category: FileCategory, count: Int, size: Int64, destination: URL?) {
        self.category = category
        self.count = count
        self.size = size
        self.destination = destination
    }
}

// MARK: - Risultato scansione

public struct ScanResult: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let folders: [FolderRef]
    public let startedAt: Date
    public var finishedAt: Date?
    public var recursive: Bool
    public var wasCancelled: Bool
    public var statistics: ScanStatistics
    public var failureNotes: [String]
    public var files: [FileItem]

    public init(
        id: UUID = UUID(),
        folders: [FolderRef],
        startedAt: Date,
        finishedAt: Date?,
        recursive: Bool,
        wasCancelled: Bool,
        statistics: ScanStatistics,
        failureNotes: [String],
        files: [FileItem]
    ) {
        self.id = id
        self.folders = folders
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.recursive = recursive
        self.wasCancelled = wasCancelled
        self.statistics = statistics
        self.failureNotes = failureNotes
        self.files = files
    }

    // MARK: Computed

    public var totalCount: Int { files.count }
    public var totalSize: Int64 { files.reduce(Int64(0)) { $0 + $1.size } }

    /// Statistiche aggregate per categoria, nell'ordine di presentazione.
    public func categoryStats() -> [CategoryStats] {
        var counts: [FileCategory: Int] = [:]
        var sizes: [FileCategory: Int64] = [:]
        var destinations: [FileCategory: URL?] = [:]

        for file in files {
            counts[file.category, default: 0] += 1
            sizes[file.category, default: 0] += file.size
            if destinations[file.category] == nil {
                destinations[file.category] = file.destinationURL
            }
        }

        return FileCategory.allCases.compactMap { category in
            guard let count = counts[category], count > 0 else { return nil }
            return CategoryStats(
                category: category,
                count: count,
                size: sizes[category] ?? 0,
                destination: destinations[category] ?? nil
            )
        }
    }
}
