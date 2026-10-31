import Foundation

/// Identifica conflitti tra file in destinazione e propone nomi alternativi
/// sicuri. Mai sovrascrivere: ogni operazione con un omonimo rinomina il file
/// in arrivo oppure salta, a scelta dell'utente.
public struct DuplicateDetector: Sendable {
    /// Dimensione della sonda usata per verificare l'identità dei contenuti.
    public let contentProbeSize: Int

    public init(contentProbeSize: Int = 64 * 1024) {
        self.contentProbeSize = contentProbeSize
    }

    // MARK: - Rilevamento

    /// Rileva un eventuale conflitto occupando il percorso `target`.
    public func conflictKind(source: URL, target: URL) -> ConflictKind {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fm.fileExists(atPath: target.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else { return .none }

        // Stesso nome: verifica se anche il contenuto è identico (sonda).
        guard
            let sourceSize = Self.fileSize(of: source),
            let targetSize = Self.fileSize(of: target),
            sourceSize == targetSize
        else { return .nameOnly }

        return Self.contentsMatch(source: source, target: target, probeSize: contentProbeSize)
            ? .nameAndContent
            : .nameOnly
    }

    // MARK: - Nomi alternativi

    /// Genera un nome non già presente in `directory`:
    /// "Fattura.pdf" occupato -> "Fattura (2).pdf", " (3)", …
    public func alternativeName(for name: String, avoidingAt directory: URL) -> String? {
        Self.alternativeName(for: name, avoidingAt: directory)
    }

    public static func alternativeName(for name: String, avoidingAt directory: URL, fm: FileManager = .default) -> String? {
        let nsName = name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        for index in 2...999 {
            let candidate = ext.isEmpty
                ? "\(base) (\(index))"
                : "\(base) (\(index)).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidate, isDirectory: false)
            if !fm.fileExists(atPath: candidateURL.path) {
                return candidate
            }
        }
        return nil
    }

    /// Nome d'emergenza per il ripristino quando 999 varianti sono occupate.
    public static func timestampedName(_ name: String) -> String {
        let nsName = name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        let stamp = Int(Date().timeIntervalSince1970) % 10_000
        return ext.isEmpty ? "\(base)-ripristino\(stamp)" : "\(base)-ripristino\(stamp).\(ext)"
    }

    // MARK: - Privati

    private static func fileSize(of url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = values?.fileSize
        return size.map(Int64.init)
    }

    /// Confronto economico: testa e coda di entrambi i file (sonda di ~64 KB
    /// per lato). Sommato alla corrispondenza di dimensione, è un ottimo
    /// indicatore di identità senza leggere il file intero.
    private static func contentsMatch(source: URL, target: URL, probeSize: Int) -> Bool {
        guard let sourceHandle = try? FileHandle(forReadingFrom: source),
              let targetHandle = try? FileHandle(forReadingFrom: target)
        else { return false }

        defer { try? sourceHandle.close(); try? targetHandle.close() }

        guard let total = fileSize(of: source), total > 0,
              let targetFile = fileSize(of: target), total == targetFile
        else { return false }
        let probe = Int64(min(probeSize, max(1, Int(total))))

        // Testa
        sourceHandle.seek(toFileOffset: 0)
        targetHandle.seek(toFileOffset: 0)
        let headSource = sourceHandle.readData(ofLength: Int(probe))
        let headTarget = targetHandle.readData(ofLength: Int(probe))
        guard headSource == headTarget else { return false }

        // Coda (se distinta dalla testa)
        let tailOffset = max(0, total - probe)
        if tailOffset > probe {
            sourceHandle.seek(toFileOffset: UInt64(tailOffset))
            targetHandle.seek(toFileOffset: UInt64(tailOffset))
            let tailSource = sourceHandle.readData(ofLength: Int(probe))
            let tailTarget = targetHandle.readData(ofLength: Int(probe))
            guard tailSource == tailTarget else { return false }
        }

        return true
    }
}
