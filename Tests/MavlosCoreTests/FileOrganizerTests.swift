import Testing
import Foundation
import MavlosCore

@Suite
final class FileOrganizerTests {

    private var root: URL

    init() {
        root = TestPaths.tempRoot()
    }

    deinit {
        TestPaths.remove(root)
    }

    private func classifiedItem(_ name: String, from folder: URL, to destination: URL) -> FileItem {
        TestFixture.item(name, in: folder, destination: destination, category: .documents, status: .classified)
    }

    // MARK: Selezione automatica

    @Test func onlyEligibleClassifiedFilesArePreselected() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let destination = TestPaths.mkdir("Arrivo", in: root)
        let ready = classifiedItem("buono.pdf", from: source, to: destination)
        let reviewed = TestFixture.item("sconosciuto.xyz", in: source, destination: nil,
                                        category: .others, status: .needsReview)

        let proposals = FileOrganizer.proposals(for: [ready, reviewed], policy: .keepBoth)
        #expect(proposals.count == 2)

        let byName = Dictionary(uniqueKeysWithValues: proposals.map { ($0.fileName, $0) })
        #expect(byName["buono.pdf"]?.isSelected == true)
        #expect(byName["sconosciuto.xyz"]?.isSelected == false)
        #expect(byName["sconosciuto.xyz"]?.isEligible == false)
    }

    @Test func batchNameCollisionRaisesWarning() {
        let destination = TestPaths.mkdir("Arrivo", in: root)
        let a = TestPaths.mkdir("Uno", in: root)
        let b = TestPaths.mkdir("Due", in: root)
        let first = classifiedItem("report.pdf", from: a, to: destination)
        let second = classifiedItem("REPORT.pdf", from: b, to: destination)

        let proposals = FileOrganizer.proposals(for: [first, second], policy: .keepBoth)

        #expect(proposals[0].warnings.isDisjoint(with: [.nameConflict]))
        #expect(proposals[1].warnings.contains(.nameConflict), "il secondo omonimo nel batch è segnalato")
        #expect(proposals[1].conflict == ConflictKind.none, "nessun omonimo reale: solo collisione nel batch")
    }

    @Test func realDiskConflictDetected() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let destination = TestPaths.mkdir("Arrivo", in: root)
        TestPaths.touch("scontrino.txt", in: destination, bytes: Data("preesistente".utf8))
        let item = classifiedItem("scontrino.txt", from: source, to: destination)

        let proposal = TestFixture.proposal(for: item)

        #expect(proposal.conflict == .nameOnly)
        #expect(proposal.warnings.contains(.nameConflict))
        #expect(proposal.warnings.contains(.identicalContent) == false)
    }

    @Test func identicalContentConflictMarked() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let destination = TestPaths.mkdir("Arrivo", in: root)
        try? Data("uguale".utf8).write(to: source.appendingPathComponent("copia.txt"))
        TestPaths.touch("copia.txt", in: destination, bytes: Data("uguale".utf8))
        let item = classifiedItem("copia.txt", from: source, to: destination)

        let proposal = TestFixture.proposal(for: item)

        #expect(proposal.conflict == .nameAndContent)
        #expect(proposal.warnings.contains(.identicalContent))
    }

    @Test func alreadyInPlaceWarning() {
        let folder = TestPaths.mkdir("Qui-va-bene", in: root)
        TestPaths.touch("stabile.txt", in: folder)
        let item = TestFixture.item("stabile.txt", in: folder, destination: folder)

        var proposal = TestFixture.proposal(for: item)
        FileOrganizer.refresh(&proposal)

        #expect(proposal.warnings.contains(.alreadyInPlace))
        #expect(proposal.isEligible == false, "destinazione = origine: niente da fare")
        #expect(proposal.note == "Il file è già nella posizione indicata.")
    }

    @Test func destinationWillBeCreatedWarning() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let future = root.appendingPathComponent("Da/Creare", isDirectory: true)
        let item = classifiedItem("piano.md", from: source, to: future)

        let proposal = TestFixture.proposal(for: item)

        #expect(proposal.warnings.contains(.destinationWillBeCreated))
        #expect(proposal.isEligible == true)
    }

    @Test func unknownTypeWarningOnNeedsReview() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let destination = TestPaths.mkdir("Arrivo", in: root)
        let item = TestFixture.item("bozza.xyz", in: source, destination: destination,
                                    category: .others, status: .needsReview)

        let proposal = TestFixture.proposal(for: item)

        #expect(proposal.warnings.contains(.unknownType))
    }

    @Test func afterCategoryChangeRefreshDetectsNewConflict() {
        let source = TestPaths.mkdir("Sorgente", in: root)
        let destination = TestPaths.mkdir("Arrivo", in: root)
        TestPaths.touch("doppio.txt", in: destination)
        let item = classifiedItem("doppio.txt", from: source, to: destination)

        var proposal = TestFixture.proposal(for: item)
        #expect(proposal.conflict == .nameOnly)

        // Sceglierne un'altra pulisce e ricalcola i conflitti.
        let second = TestPaths.mkdir("Libera", in: root)
        proposal.item.destinationURL = second
        FileOrganizer.refresh(&proposal)

        #expect(proposal.conflict == .none)
        #expect(proposal.warnings.contains(.nameConflict) == false)
    }

    @Test func warningDescriptionsAreHumanReadable() {
        #expect(FileOrganizer.warningDescription(.nameConflict).isEmpty == false)
        #expect(FileOrganizer.warningDescription(.nameConflict) != FileOrganizer.warningDescription(.alreadyInPlace))
    }
}
