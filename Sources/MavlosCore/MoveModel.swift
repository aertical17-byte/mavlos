import Foundation

// MARK: - Politica di gestione duplicati

/// Come gestire un conflitto con un file già presente nella destinazione.
/// Non esiste alcuna politica distruttiva: il file originale non viene
/// mai sovrascritto né eliminato.
public enum ConflictPolicy: String, Codable, Sendable, CaseIterable {
    /// Mantiene entrambi i file rinominando quello in arrivo ("nome (2).ext").
    case keepBoth
    /// Salta l'operazione lasciando il file nella posizione originale.
    case skip

    public var displayName: String {
        switch self {
        case .keepBoth: return "Mantieni entrambi (rinomina)"
        case .skip: return "Salta l'operazione"
        }
    }
}

/// Tipo di conflitto rilevato in destinazione.
public enum ConflictKind: String, Codable, Sendable {
    case none
    /// Esiste già un file con lo stesso nome.
    case nameOnly
    /// Nome e contenuto verificati come identici.
    case nameAndContent
}

// MARK: - Avvisi

public enum MoveWarning: String, Codable, Sendable, Hashable, CaseIterable {
    /// Nella destinazione è già presente un file con lo stesso nome.
    case nameConflict
    /// Il file in destinazione ha contenuto identico.
    case identicalContent
    /// Tipologia non riconosciuta: destinazione non determinata automaticamente.
    case unknownType
    /// La cartella di destinazione sarà creata al momento dello spostamento.
    case destinationWillBeCreated
    /// La destinazione coincide con l'attuale posizione del file.
    case alreadyInPlace
}

// MARK: - Proposta di spostamento

/// Elemento di anteprima che unisce i dati del file alle decisioni operative
/// (selezione, categoria, destinazione, politica conflitti).
public struct MoveProposal: Identifiable, Hashable, Sendable {
    public var item: FileItem
    public var isSelected: Bool
    public var conflict: ConflictKind
    public var warnings: Set<MoveWarning>
    public var policy: ConflictPolicy
    /// Nota leggibile per l'utente (es. "già nella cartella di destinazione").
    public var note: String?

    public var id: UUID { item.id }
    public var fileName: String { item.displayName }

    init(
        item: FileItem,
        isSelected: Bool,
        conflict: ConflictKind,
        warnings: Set<MoveWarning>,
        policy: ConflictPolicy,
        note: String? = nil
    ) {
        self.item = item
        self.isSelected = isSelected
        self.conflict = conflict
        self.warnings = warnings
        self.policy = policy
        self.note = note
    }

    /// La proposta può essere eseguita: c'è una destinazione valida e non coincide con l'origine.
    public var isEligible: Bool {
        guard let destination = item.destinationURL else { return false }
        return destination != item.originalFolder
    }

    /// Nome previsto in destinazione dopo l'eventuale rinomina.
    public func expectedFinalName(resolved conflict: ConflictKind = .none) -> String { item.displayName }
}

// MARK: - Esito operazione

public enum MoveOutcome: String, Codable, Sendable {
    case moved
    case skipped
    case failed
}

public struct MoveResult: Identifiable, Sendable, Hashable {
    public let proposalID: UUID
    public let fileName: String
    public let outcome: MoveOutcome
    /// Percorso finale dopo lo spostamento (per .moved).
    public let finalURL: URL?
    /// Messaggio leggibile per skipped/failed.
    public let message: String?
    public var id: UUID { proposalID }

    public init(proposalID: UUID, fileName: String, outcome: MoveOutcome, finalURL: URL?, message: String?) {
        self.proposalID = proposalID
        self.fileName = fileName
        self.outcome = outcome
        self.finalURL = finalURL
        self.message = message
    }
}

public struct OrganizationRun: Sendable, Hashable {
    public let startedAt: Date
    public let finishedAt: Date
    public let results: [MoveResult]

    public var movedCount: Int { results.filter { $0.outcome == .moved }.count }
    public var skippedCount: Int { results.filter { $0.outcome == .skipped }.count }
    public var failedCount: Int { results.filter { $0.outcome == .failed }.count }
    public var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }

    /// Riepilogo testuale dello stato (completata / parzialmente completata).
    public var stateDescription: String {
        if failedCount == 0 && skippedCount == 0 { return "Completata" }
        if movedCount == 0 { return "Non riuscita" }
        return "Parzialmente completata"
    }
}
