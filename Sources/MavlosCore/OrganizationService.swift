import Foundation

/// Avanzamento di un'organizzazione in corso.
public struct MoveProgress: Equatable, Sendable {
    public var completed: Int
    public var total: Int
    public var currentFile: String?

    public init(completed: Int, total: Int, currentFile: String?) {
        self.completed = completed
        self.total = total
        self.currentFile = currentFile
    }
}

/// Orchestratore delle operazioni di organizzazione: applica le proposte
/// selezionate una alla volta, registra ogni risultato e prosegue
/// senza interrompere tutto in caso di errore.
public enum OrganizationService {

    /// Esegue le proposte selezionate. Ogni spostamento è indipendente:
    /// un fallimento non blocca gli altri.
    public static func organize(
        proposals: [MoveProposal],
        journal: OperationJournal,
        progress: (@Sendable (MoveProgress) -> Void)? = nil
    ) async -> OrganizationRun {
        let pending = proposals.filter { $0.isSelected && $0.isEligible }
        let startedAt = Date()
        var results: [MoveResult] = []

        for proposal in pending {
            let result = FileMover.move(proposal, journal: journal)
            results.append(result)
            let snapshot = MoveProgress(completed: results.count, total: pending.count, currentFile: proposal.fileName)
            progress?(snapshot)
        }

        return OrganizationRun(startedAt: startedAt, finishedAt: Date(), results: results)
    }
}
