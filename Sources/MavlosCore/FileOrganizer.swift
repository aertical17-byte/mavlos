import Foundation

/// Costruisce le proposte di spostamento a partire dai file classificati.
/// Gestisce conflitti con il disco reale, collisioni interne al batch,
/// avvisi e stato complessivo dell'anteprima.
public enum FileOrganizer {

    /// Crea l'elenco di proposte a partire dai file classificati.
    /// - Parameters:
    ///   - files: file classificati dalla scansione.
    ///   - policy: politica predefinita di gestione dei conflitti (dai settings).
    ///   - detector: rileva conflitti con il filesystem.
    public static func proposals(
        for files: [FileItem],
        policy: ConflictPolicy,
        detector: DuplicateDetector = DuplicateDetector()
    ) -> [MoveProposal] {
        var batchRegistry: [String: Set<String>] = [:]
        var list: [MoveProposal] = []
        list.reserveCapacity(files.count)

        for item in files {
            var proposal = MoveProposal(item: item, isSelected: false, conflict: .none, warnings: [], policy: policy)
            refresh(&proposal, detector: detector, batchRegistry: &batchRegistry, registerInBatch: true)
            proposal.isSelected = proposal.isEligible && proposal.item.status == .classified
            list.append(proposal)
        }
        return list
    }

    /// Ricalcola conflitti e avvisi per una singola proposta
    /// (chiamato dopo modifiche di categoria o destinazione).
    public static func refresh(_ proposal: inout MoveProposal, detector: DuplicateDetector = DuplicateDetector()) {
        var registry: [String: Set<String>] = [:]
        refresh(&proposal, detector: detector, batchRegistry: &registry, registerInBatch: false)
    }

    /// Versione con registro dei nomi già assegnati durante l'anteprima
    /// (per rilevare due file di origine diversa con lo stesso nome verso
    /// la stessa cartella di destinazione).
    static func refresh(
        _ proposal: inout MoveProposal,
        detector: DuplicateDetector,
        batchRegistry: inout [String: Set<String>],
        registerInBatch: Bool
    ) {
        let item = proposal.item
        var warnings: Set<MoveWarning> = []
        var note: String? = nil
        var conflict: ConflictKind = .none

        if item.status == .needsReview {
            warnings.insert(.unknownType)
        }

        if let destination = item.destinationURL {
            if destination.standardizedFileURL.path == item.originalFolder.standardizedFileURL.path {
                warnings.insert(.alreadyInPlace)
                note = "Il file è già nella posizione indicata."
            } else {
                // Conflitto con il disco reale: esiste già un omonimo?
                let candidate = destination.appendingPathComponent(item.displayName)
                conflict = detector.conflictKind(source: item.url, target: candidate)
                if conflict != .none {
                    warnings.insert(.nameConflict)
                    if conflict == .nameAndContent {
                        warnings.insert(.identicalContent)
                    }
                }

                if !FileManager.default.fileExists(atPath: destination.path) {
                    warnings.insert(.destinationWillBeCreated)
                }

                if registerInBatch {
                    let folderKey = destination.standardizedFileURL.path
                    let nameKey = item.displayName.lowercased()
                    if let names = batchRegistry[folderKey] {
                        if names.contains(nameKey) {
                            warnings.insert(.nameConflict)
                        }
                        batchRegistry[folderKey] = names.union([nameKey])
                    } else {
                        batchRegistry[folderKey] = [nameKey]
                    }
                }
            }
        }

        proposal.conflict = conflict
        proposal.warnings = warnings
        proposal.note = note
    }

    /// Ricalcola le collisioni interne su un intero set di proposte.
    public static func rebuildBatchCollisions(_ proposals: inout [MoveProposal]) {
        var registry: [String: Set<String>] = [:]
        for index in proposals.indices {
            var proposal = proposals[index]
            refresh(&proposal, detector: DuplicateDetector(), batchRegistry: &registry, registerInBatch: true)
            proposals[index] = proposal
        }
    }

    // MARK: - Descrizioni avvisi

    public static func warningDescription(_ warning: MoveWarning) -> String {
        switch warning {
        case .nameConflict: return "nome già presente"
        case .identicalContent: return "contenuto identico"
        case .unknownType: return "da verificare"
        case .destinationWillBeCreated: return "cartella da creare"
        case .alreadyInPlace: return "già a posto"
        }
    }
}
