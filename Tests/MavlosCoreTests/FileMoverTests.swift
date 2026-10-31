import Testing
import Foundation
import MavlosCore

@Suite
final class FileMoverTests {

    private var root: URL
    private var origin: URL
    private var destination: URL
    private var journal: OperationJournal
    private var journalURL: URL

    init() {
        root = TestPaths.tempRoot()
        origin = TestPaths.mkdir("Origine", in: root)
        destination = TestPaths.mkdir("Destinazione", in: root)
        journalURL = root.appendingPathComponent("journal.json")
        journal = OperationJournal(storeURL: journalURL)
    }

    deinit {
        TestPaths.remove(root)
    }

    // MARK: Helper

    private func makeProposal(
        named name: String,
        in folder: URL? = nil,
        to target: URL? = nil,
        policy: ConflictPolicy = .keepBoth
    ) -> MoveProposal {
        let sourceFolder = folder ?? origin
        TestPaths.touch(name, in: sourceFolder)
        let item = TestFixture.item(name, in: sourceFolder, destination: target ?? destination)
        var proposal = TestFixture.proposal(for: item, policy: policy)
        proposal.isSelected = true
        FileOrganizer.refresh(&proposal)
        return proposal
    }

    // MARK: Spostamento base

    @Test func moveRelocatesFileAndRecordsInJournal() {
        let proposal = makeProposal(named: "relazione.pdf")
        let result = FileMover.move(proposal, journal: journal)

        #expect(result.outcome == .moved)
        #expect(result.finalURL?.path == destination.appendingPathComponent("relazione.pdf").path)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("relazione.pdf").path))
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("relazione.pdf").path) == false)
        #expect(journal.allRecords().count == 1)
        #expect(journal.allRecords().first?.fileName == "relazione.pdf")
        #expect(journal.allRecords().first?.kind == .move)
    }

    @Test func moveWithoutJournalRegistryStaysEmpty() {
        let proposal = makeProposal(named: "solo-spostamento.txt")
        let result = FileMover.move(proposal, journal: nil)
        #expect(result.outcome == .moved)
        #expect(journal.allRecords().isEmpty == true, "senza journal il registro resta vuoto")
    }

    @Test func moveCreatesMissingDestination() {
        let missing = root.appendingPathComponent("Nuova/Da/Creare", isDirectory: true)
        let proposal = makeProposal(named: "bozza.md", to: missing)
        let result = FileMover.move(proposal, journal: nil)
        #expect(result.outcome == .moved)
        #expect(FileManager.default.fileExists(atPath: missing.appendingPathComponent("bozza.md").path))
    }

    @Test func moveWithoutDestinationIsSkipped() {
        TestPaths.touch("orfano.txt", in: origin)
        let item = TestFixture.item("orfano.txt", in: origin, destination: nil,
                                    category: .others, status: .needsReview)
        let proposal = TestFixture.proposal(for: item)

        let result = FileMover.move(proposal, journal: nil)
        #expect(result.outcome == .skipped)
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("orfano.txt").path))
    }

    @Test func moveIntoSourceFolderIsSkippedAsAlreadyInPlace() {
        TestPaths.touch("già-a-posto.txt", in: origin)
        let item = TestFixture.item("già-a-posto.txt", in: origin, destination: origin)
        let proposal = TestFixture.proposal(for: item)

        let result = FileMover.move(proposal, journal: nil)
        #expect(result.outcome == .skipped)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("già-a-posto.txt").path) == false)
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("già-a-posto.txt").path))
    }

    @Test func moveMissingSourceFails() {
        let item = TestFixture.item("sparito.txt", in: origin, destination: destination)
        var proposal = TestFixture.proposal(for: item)
        proposal.isSelected = true
        FileOrganizer.refresh(&proposal)

        let result = FileMover.move(proposal, journal: journal)
        #expect(result.outcome == .failed, "la sorgente non esiste più: nessun mistero, niente toccato")
        #expect(result.message != nil)
    }

    // MARK: Conflitti

    @Test func conflictWithSkipPolicyLeavesEverythingUntouched() {
        TestPaths.touch("relazione.pdf", in: destination, bytes: Data("esistente".utf8))
        let proposal = makeProposal(named: "relazione.pdf", policy: .skip)

        let result = FileMover.move(proposal, journal: journal)

        #expect(result.outcome == .skipped)
        #expect(journal.allRecords().isEmpty == true, "un'operazione saltata non è registrata")
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("relazione.pdf").path))
        #expect(String(data: (try? Data(contentsOf: destination.appendingPathComponent("relazione.pdf"))) ?? Data(), encoding: .utf8) == "esistente")
    }

    @Test func conflictWithKeepBothRenamesIncomingFile() {
        TestPaths.touch("relazione.pdf", in: destination, bytes: Data("esistente".utf8))
        let proposal = makeProposal(named: "relazione.pdf", policy: .keepBoth)

        let result = FileMover.move(proposal, journal: journal)

        #expect(result.outcome == .moved)
        #expect(result.finalURL?.lastPathComponent == "relazione (2).pdf")
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("relazione.pdf").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("relazione (2).pdf").path))
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("relazione.pdf").path) == false)
        #expect(journal.allRecords().contains { $0.finalPath == result.finalURL?.path })
    }

    @Test func sequentialKeepBothUsesThirdVariant() {
        TestPaths.touch("foto.png", in: destination)
        TestPaths.touch("foto (2).png", in: destination)
        let proposal = makeProposal(named: "foto.png", policy: .keepBoth)

        let result = FileMover.move(proposal, journal: journal)

        #expect(result.outcome == .moved)
        #expect(result.finalURL?.lastPathComponent == "foto (3).png")
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("foto.png").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("foto (2).png").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("foto (3).png").path))
    }

    // MARK: Annullamento

    @Test func undoRestoresOriginalLocation() {
        let proposal = makeProposal(named: "lettera.txt")
        let result = FileMover.move(proposal, journal: journal)
        #expect(result.outcome == .moved)

        guard let record = journal.allRecords().last else {
            Issue.record("record mancante nel journal")
            return
        }
        let outcome = FileMover.undo(record)

        #expect(outcome.success == true)
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("lettera.txt").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("lettera.txt").path) == false)
        #expect(journal.removeLast() != nil, "il registro scorre dopo l'annullamento")
    }

    @Test func undoWhenOriginalSpotOccupiedRenamesRestore() {
        let proposal = makeProposal(named: "lettera.txt")
        _ = FileMover.move(proposal, journal: journal)
        // Nel frattempo compare un omonimo nella cartella di origine.
        TestPaths.touch("lettera.txt", in: origin, bytes: Data("nuovo occupante".utf8))

        guard let record = journal.allRecords().last else {
            Issue.record("record mancante nel journal")
            return
        }
        let outcome = FileMover.undo(record)

        #expect(outcome.success == true)
        #expect(outcome.message.contains("lettera (2).txt"))
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("lettera.txt").path))
        #expect(FileManager.default.fileExists(atPath: origin.appendingPathComponent("lettera (2).txt").path))
    }

    @Test func undoMissingFileFailsGracefully() {
        let record = OperationRecord(
            fileName: "fantasma.txt",
            originalPath: origin.appendingPathComponent("fantasma.txt").path,
            finalPath: destination.appendingPathComponent("fantasma.txt").path,
            fileSize: 1,
            category: nil
        )
        let outcome = FileMover.undo(record)
        #expect(outcome.success == false)
        #expect(outcome.message.isEmpty == false)
    }

    // MARK: Journal persistente

    @Test func journalPersistsAcrossInstances() {
        let proposal = makeProposal(named: "documento.docx")
        _ = FileMover.move(proposal, journal: journal)

        let reloaded = OperationJournal(storeURL: journalURL)
        let records = reloaded.allRecords()
        #expect(records.count == 1)
        #expect(records.first?.fileName == "documento.docx")
        guard let record = records.first else {
            Issue.record("record decodificato in modo incompleto")
            return
        }

        // removeLast persistisce anche su disco.
        let removed = reloaded.removeLast()
        #expect(removed?.id == record.id)
        #expect(OperationJournal(storeURL: journalURL).isEmpty == true)
    }

    @Test func journalCapsHistoryToMaxRecords() {
        let limit = 500
        for index in 0..<(limit + 5) {
            journal.append(OperationRecord(
                fileName: "f\(index).txt",
                originalPath: origin.appendingPathComponent("f\(index).txt").path,
                finalPath: destination.appendingPathComponent("f\(index).txt").path,
                fileSize: 1,
                category: nil
            ))
        }
        let records = journal.allRecords()
        #expect(records.count == limit)
        #expect(records.first?.fileName == "f5.txt")
        #expect(records.last?.fileName == "f\(limit + 4).txt")
    }
}
