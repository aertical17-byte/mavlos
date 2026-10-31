import Foundation

/// Una operazione concluse e registrata, necessaria all'annullamento.
public struct OperationRecord: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case move }

    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public let fileName: String
    /// Percorso di origine (a cui il file torna se l'operazione viene annullata).
    public let originalPath: String
    /// Percorso finale immediatamente dopo l'operazione.
    public let finalPath: String
    public let fileSize: Int64
    public let category: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: Kind = .move,
        fileName: String,
        originalPath: String,
        finalPath: String,
        fileSize: Int64,
        category: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.fileName = fileName
        self.originalPath = originalPath
        self.finalPath = finalPath
        self.fileSize = fileSize
        self.category = category
    }
}

/// Registro persistente (JSON append-only) delle operazioni svolte.
/// Conservato in Application Support/Mavlos; non memorizza il contenuto dei file.
public final class OperationJournal: @unchecked Sendable {
    private let lock = NSLock()
    private let fileURL: URL
    private var records: [OperationRecord] = []
    private let maxRecords = 500

    /// Posizione predefinita del registro.
    public static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Mavlos/journal.json", isDirectory: false)
    }

    public init(storeURL: URL = OperationJournal.defaultStoreURL()) {
        self.fileURL = storeURL
        load()
    }

    // MARK: - API

    public func allRecords() -> [OperationRecord] {
        lock.lock(); defer { lock.unlock() }
        return records
    }

    public var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return records.isEmpty
    }

    /// Aggiunge e salva subito un record: un crash non deve disallineare il registro.
    public func append(_ record: OperationRecord) {
        lock.lock()
        records.append(record)
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
        let snapshot = records
        lock.unlock()
        persist(snapshot)
    }

    /// Rimuove l'ultimo record dal registro (dopo un annullamento riuscito).
    @discardableResult
    public func removeLast() -> OperationRecord? {
        lock.lock()
        let removed = records.popLast()
        let snapshot = records
        lock.unlock()
        persist(snapshot)
        return removed
    }

    public func remove(recordID: UUID) {
        lock.lock()
        records.removeAll { $0.id == recordID }
        let snapshot = records
        lock.unlock()
        persist(snapshot)
    }

    // MARK: - Persistenza

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([OperationRecord].self, from: data)
        else { return }
        lock.lock()
        records = decoded
        lock.unlock()
    }

    private func persist(_ snapshot: [OperationRecord]) {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Il registro non deve bloccare le operazioni: la scrittura fallita
            // è silenziosa, l'annullamento segnalerà "non possibile" se manca il record.
        }
    }
}
