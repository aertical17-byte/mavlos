import Foundation

/// Esecutore degli spostamenti con tutti i controlli di sicurezza:
/// niente cancellazioni, niente sovrascritture, niente cicli,
/// ogni operazione registrata per l'annullamento.
public enum FileMover {

    // MARK: - Spostamento

    /// Esegue una proposta di spostamento e registra l'esito nel journal.
    public static func move(
        _ proposal: MoveProposal,
        journal: OperationJournal?,
        detector: DuplicateDetector = DuplicateDetector()
    ) -> MoveResult {
        let item = proposal.item

        guard proposal.isEligible, let destination = item.destinationURL else {
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .skipped,
                finalURL: nil, message: "Nessuna destinazione valida: operazione saltata."
            )
        }

        let fm = FileManager.default

        // 1. La sorgente deve esistere ancora.
        guard fm.fileExists(atPath: item.url.path) else {
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .failed,
                finalURL: nil, message: "Il file non è più presente in \(PathDefaults.compactPath(item.originalFolder))."
            )
        }

        // 2. La destinazione deve essere una cartella reale.
        var destIsDirectory: ObjCBool = false
        let destExists = fm.fileExists(atPath: destination.path, isDirectory: &destIsDirectory)
        if destExists && !destIsDirectory.boolValue {
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .failed,
                finalURL: nil, message: "«\(PathDefaults.compactPath(destination))» non è una cartella."
            )
        }

        // 3. Crea la destinazione se manca.
        do {
            if !destExists {
                try PermissionManager.ensureDirectory(at: destination)
            }
        } catch {
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .failed,
                finalURL: nil, message: describe(error)
            )
        }

        // 4. Conflitti: mai sovrascrivere.
        var target = destination.appendingPathComponent(item.displayName)
        if detector.conflictKind(source: item.url, target: target) != .none {
            switch proposal.policy {
            case .skip:
                return MoveResult(
                    proposalID: item.id, fileName: item.displayName, outcome: .skipped,
                    finalURL: nil, message: "Esiste già «\(item.displayName)»: operazione saltata."
                )
            case .keepBoth:
                guard let alternative = detector.alternativeName(for: item.displayName, avoidingAt: destination) else {
                    return MoveResult(
                        proposalID: item.id, fileName: item.displayName, outcome: .failed,
                        finalURL: nil, message: MavlosError.conflictUnresolvable(path: item.displayName).errorDescription ?? "Conflitto non risolvibile."
                    )
                }
                target = destination.appendingPathComponent(alternative)
            }
        }

        // 5. Guardia anti-ciclo: la destinazione non deve contenere la sorgente.
        if PathDefaults.isInside(item.url, of: target) || target == item.url {
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .failed,
                finalURL: nil, message: MavlosError.cycleGuard(path: item.displayName).errorDescription ?? "Ciclo rilevato."
            )
        }

        // 6. Spostamento effettivo.
        do {
            try fm.moveItem(at: item.url, to: target)
        } catch {
            // Difesa in più: se l'omonimo è comparsa nel frattempo, riprova
            // con un nome alternativo invece di sovrascrivere.
            let nsError = error as NSError
            if nsError.code == NSFileWriteFileExistsError && proposal.policy == .keepBoth,
               let alternative = detector.alternativeName(for: item.displayName, avoidingAt: destination) {
                let retryTarget = destination.appendingPathComponent(alternative)
                do {
                    if !FileManager.default.fileExists(atPath: retryTarget.path) {
                        try fm.moveItem(at: item.url, to: retryTarget)
                        registerMove(item: item, from: item.url, to: retryTarget, journal: journal)
                        return MoveResult(proposalID: item.id, fileName: item.displayName, outcome: .moved, finalURL: retryTarget, message: nil)
                    }
                } catch {}
            }
            return MoveResult(
                proposalID: item.id, fileName: item.displayName, outcome: .failed,
                finalURL: nil, message: describe(error)
            )
        }

        // 7. Registrazione per l'annullamento.
        registerMove(item: item, from: item.url, to: target, journal: journal)

        return MoveResult(
            proposalID: item.id, fileName: item.displayName, outcome: .moved,
            finalURL: target, message: nil
        )
    }

    private static func registerMove(item: FileItem, from: URL, to: URL, journal: OperationJournal?) {
        guard let journal else { return }
        let record = OperationRecord(
            fileName: item.displayName,
            originalPath: from.path,
            finalPath: to.path,
            fileSize: item.size,
            category: item.category.rawValue
        )
        journal.append(record)
    }

    // MARK: - Annullamento

    public struct UndoOutcome: Sendable {
        public let success: Bool
        public let message: String

        public init(success: Bool, message: String) {
            self.success = success
            self.message = message
        }
    }

    /// Riporta l'ultimo file spostato al percorso originale, con verifiche
    /// su disponibilità e conflitti. Non elimina e non sovrascrive nulla.
    public static func undo(
        _ record: OperationRecord,
        detector: DuplicateDetector = DuplicateDetector()
    ) -> UndoOutcome {
        let fm = FileManager.default
        let original = URL(fileURLWithPath: record.originalPath)
        let moved = URL(fileURLWithPath: record.finalPath)

        guard fm.fileExists(atPath: moved.path) else {
            return UndoOutcome(
                success: false,
                message: "Ripristino non possibile: «\(record.fileName)» non è più presente in «\(PathDefaults.compactPath(moved.deletingLastPathComponent()))»."
            )
        }

        let originalFolder = original.deletingLastPathComponent()
        if !fm.fileExists(atPath: originalFolder.path) {
            do {
                try PermissionManager.ensureDirectory(at: originalFolder)
            } catch {
                return UndoOutcome(success: false, message: describe(error))
            }
        }

        var restoreTarget = original
        var alternativeNote = ""
        if fm.fileExists(atPath: restoreTarget.path) {
            let alternative = DuplicateDetector.alternativeName(for: record.fileName, avoidingAt: originalFolder)
                ?? DuplicateDetector.timestampedName(record.fileName)
            restoreTarget = originalFolder.appendingPathComponent(alternative)
            alternativeNote = " (rinominato in “\(alternative)”)"
        }

        do {
            try fm.moveItem(at: moved, to: restoreTarget)
        } catch {
            return UndoOutcome(success: false, message: describe(error))
        }

        return UndoOutcome(success: true, message: "«\(record.fileName)» riportato in \(PathDefaults.compactPath(originalFolder))\(alternativeNote).")
    }

    // MARK: - Diagnostica

    /// Converte un errore del filesystem in un messaggio comprensibile.
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.domain {
        case NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileWriteNoPermissionError:
                return "Permesso negato. Concedi a Mavlos l'accesso alla cartella (Impostazioni di Sistema → Privacy e sicurezza → File e cartelle)."
            case NSFileWriteFileExistsError:
                return "Esiste già un file con lo stesso nome: niente è stato sovrascritto."
            case NSFileReadUnknownError, NSFileReadNoPermissionError:
                return "Lettura non possibile: permessi insufficienti."
            case NSFileWriteUnknownError:
                return "Spostamento non riuscito: \(nsError.localizedDescription)"
            default:
                return "Operazione non riuscita: \(nsError.localizedDescription)"
            }
        case NSPOSIXErrorDomain:
            switch nsError.code {
            case 13: return "Permesso negato dalla cartella di destinazione."
            case 21: return "La destinazione indicata non è una cartella."
            default: return "Errore di sistema (\(nsError.code)): \(nsError.localizedDescription)"
            }
        default:
            return "Errore: \(nsError.localizedDescription)"
        }
    }
}
