import Foundation

/// Stato di accessibilità di una cartella per l'app.
public enum FolderAccessibility: Equatable, Sendable {
    case accessible
    case missing
    case restricted

    public var description: String {
        switch self {
        case .accessible: return "accessibile"
        case .missing: return "inesistente"
        case .restricted: return "permessi insufficienti"
        }
    }
}

/// Gestione dei permessi del filesystem di macOS.
///
/// Mavlos rispetta i controlli di sistema (TCC): non richiede Accesso completo
/// al disco e non tenta mai di aggirare le protezioni. L'accesso alle cartelle
/// scelte dall'utente arriva dal selettore nativo (NSOpenPanel) e, quando
/// necessario, da Security-Scoped Bookmarks.
public enum PermissionManager {

    /// Verifica la lettura di un percorso.
    public static func isReadable(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    /// Stato di accessibilità in lettura di una cartella.
    public static func accessibility(of url: URL) -> FolderAccessibility {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return .missing }
        guard isDirectory.boolValue else { return .restricted }
        guard isReadable(url) else { return .restricted }
        return .accessible
    }

    /// Crea la cartella di destinazione se assente e verifica scrivibilità.
    public static func ensureDirectory(at url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        guard fm.isWritableFile(atPath: url.path) else {
            throw MavlosError.noWritePermission(path: url.path)
        }
    }

    /// Preflight di scrittura: crea (se manca) la cartella e scrive/elimina
    /// un file-probe invisibile. È il controllo affidabile della scrivibilità
    /// reale e ha anche l'effetto di far comparire l'eventuale richiesta di
    /// permesso TCC mentre l'app è in primo piano.
    public static func verifyWritable(_ directory: URL) throws {
        try ensureDirectory(at: directory)
        let probe = directory.appendingPathComponent(".mavlos-access-probe")
        try Data().write(to: probe, options: .atomic)
        try? FileManager.default.removeItem(at: probe)
    }

    /// Spiegazione semplice della richiesta d'accesso (mostrata la prima volta).
    public static func accessExplanation(for url: URL) -> String {
        "Mavlos leggerà nomi, tipologie e dimensioni dei file per proporti dove spostarli. " +
        "Nessun file e nessun dato lascia il tuo Mac."
    }
}

// MARK: - Errori

public enum MavlosError: LocalizedError, Sendable {
    case missingFolder(path: String)
    case noWritePermission(path: String)
    case fileMissing(path: String)
    case conflictUnresolvable(path: String)
    case cycleGuard(path: String)
    case generic(message: String)

    public var errorDescription: String? {
        switch self {
        case .missingFolder(let p):
            return "La cartella «\(p)» non esiste."
        case .noWritePermission(let p):
            return "Permessi insufficienti per scrivere in «\(p)»."
        case .fileMissing(let p):
            return "Il file «\(p)» non è più presente."
        case .conflictUnresolvable(let p):
            return "Impossibile risolvere il conflitto per «\(p)»."
        case .cycleGuard(let p):
            return "Operazione annullata per prevenire un ciclo: «\(p)»."
        case .generic(let m):
            return m
        }
    }
}
