import Testing
import Foundation
import MavlosCore

/// Le scansioni avvengono esclusivamente dentro una cartella temporanea.
@Suite
final class FileScannerTests {

    private var root: URL
    private let book = RuleBook()

    init() {
        root = TestPaths.tempRoot()
    }

    deinit {
        TestPaths.remove(root)
    }

    // MARK: Non-recursive vs recursive

    @Test func nonRecursiveScanOnlyTopLevel() async {
        let nested = TestPaths.mkdir("Sotto", in: root)
        TestPaths.touch("foto.jpg", in: root)
        TestPaths.touch("relazione.pdf", in: nested)
        TestPaths.touch("brano.mp3", in: nested)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: false,
            ruleBook: book
        )

        #expect(result.wasCancelled == false)
        #expect(result.totalCount == 1)
        #expect(result.files.first?.displayName == "foto.jpg")
        #expect(result.statistics.analyzedCount == 1)
        #expect(result.statistics.classifiedCount == 1)
    }

    @Test func recursiveScanIncludesSubfolders() async {
        let nested = TestPaths.mkdir("Sotto", in: root)
        TestPaths.touch("foto.jpg", in: root)
        TestPaths.touch("relazione.pdf", in: nested)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 2)
        #expect(result.statistics.analyzedCount == 2)
        #expect(Set(result.files.map(\.displayName)) == ["foto.jpg", "relazione.pdf"])
    }

    @Test func recursiveScanFollowsMultipleLevels() async {
        let level1 = TestPaths.mkdir("Uno", in: root)
        let level2 = TestPaths.mkdir("Due", in: level1)
        let level3 = TestPaths.mkdir("Tre", in: level2)
        TestPaths.touch("fondo.mp4", in: level3)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 1)
        #expect(result.files.first?.category == .video)
    }

    // MARK: Esclusioni di sicurezza

    @Test func hiddenFilesAndFoldersAreSkipped() async {
        TestPaths.touch(".DS_Store", in: root)
        TestPaths.touch("visibile.txt", in: root)
        let hiddenDir = TestPaths.mkdir(".cartella", in: root)
        TestPaths.touch("dentro.txt", in: hiddenDir)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 1)
        #expect(result.files.first?.displayName == "visibile.txt")
    }

    @Test func symbolicLinksAreNotFollowed() async {
        TestPaths.touch("originale.txt", in: root)
        try? FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent("collegamento.txt").path,
            withDestinationPath: root.appendingPathComponent("originale.txt").path
        )
        TestPaths.touch("normale.pdf", in: root)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        let names = Set(result.files.map(\.displayName))
        #expect(names.contains("collegamento.txt") == false, "i link simbolici sono esclusi")
        #expect(names == ["originale.txt", "normale.pdf"])
        #expect(result.statistics.skippedCount >= 1)
    }

    @Test func packagesAreExcluded() async {
        let appBundle = TestPaths.mkdir("Applicazione.app", in: root)
        let contents = TestPaths.mkdir("Contents", in: appBundle)
        TestPaths.touch("eseguibile", in: contents)
        TestPaths.touch("allegato.pdf", in: root)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 1, "solo i file normali: i pacchetti .app restano intatti")
        #expect(result.files.first?.pathExtension == "pdf")
    }

    @Test func protectedSelectionIsRefused() async {
        let library = TestPaths.mkdir("Library", in: root)
        TestPaths.touch("privato.txt", in: library)
        TestPaths.touch("ok.jpg", in: root)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: library, displayName: "Library")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 0)
        #expect(result.failureNotes.isEmpty == false, "serve una nota per l'utente")
        #expect(result.failureNotes.contains { $0.contains("Library") })
    }

    @Test func missingFolderProducesNote() async {
        let ghost = root.appendingPathComponent("Fantasma")
        let result = await FileScanner.scan(
            folders: [FolderRef(url: ghost, displayName: "Fantasma")],
            recursive: true,
            ruleBook: book
        )
        #expect(result.totalCount == 0)
        #expect(result.failureNotes.contains { $0.contains("Fantasma") })
    }

    // MARK: Classificazione e statistiche

    @Test func classificationAppliedDuringScan() async {
        TestPaths.touch("presentazione.key", in: root)
        TestPaths.touch("sconosciuto.xyzxyz", in: root)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        let byName = Dictionary(uniqueKeysWithValues: result.files.map { ($0.displayName, $0) })
        #expect(byName["presentazione.key"]?.category == .documents)
        #expect(byName["presentazione.key"]?.status == .classified)
        #expect(byName["sconosciuto.xyzxyz"]?.status == .needsReview)
        #expect(result.statistics.classifiedCount == 1)
    }

    @Test func realSizesAreRecorded() async {
        TestPaths.touch("pesante.jpg", in: root, bytes: Data(repeating: 7, count: 4096))

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.files.first?.size == 4096)
        #expect(result.totalSize == 4096)
    }

    @Test func categoryStatsAggregateCountsAndSizes() async {
        TestPaths.touch("uno.jpg", in: root, bytes: Data(repeating: 1, count: 10))
        TestPaths.touch("due.jpg", in: root, bytes: Data(repeating: 2, count: 20))
        TestPaths.touch("tre.pdf", in: root, bytes: Data(repeating: 3, count: 30))

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book
        )

        let stats = result.categoryStats()
        let images = stats.first { $0.category == .images }
        let documents = stats.first { $0.category == .documents }
        #expect(images?.count == 2)
        #expect(images?.size == 30)
        #expect(documents?.count == 1)
    }

    // MARK: Avanzamento e annullamento

    @Test func progressSnapshotsReportRealCounts() async {
        TestPaths.touch("a.jpg", in: root)
        TestPaths.touch("b.jpg", in: root)
        TestPaths.touch("c.pdf", in: root)

        var snapshots: [ScanProgressSnapshot] = []
        let lock = NSLock()
        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book,
            progress: { snapshot in
                lock.lock()
                snapshots.append(snapshot)
                lock.unlock()
            }
        )
        _ = snapshots.count

        #expect(snapshots.isEmpty == false)
        #expect(snapshots.contains { $0.phase == .completed })
        #expect(snapshots.contains { $0.found == 3 })
        #expect(result.totalCount == 3)
        #expect(result.startedAt <= result.finishedAt ?? Date())
    }

    @Test func cancellationFromProgressCallbackStopsScan() async {
        for index in 0..<300 { TestPaths.touch("file-\(index).dat", in: root) }

        let result = await FileScanner.scan(
            folders: [FolderRef(url: root, displayName: "Radice")],
            recursive: true,
            ruleBook: book,
            progress: { snapshot in
                // Il compito della scansione si annulla da solo alla prima
                // fotografia rilevata: l'esito deve restare parziale, non completo.
                guard snapshot.phase == .scanning else { return }
                withUnsafeCurrentTask { $0?.cancel() }
            }
        )

        #expect(result.wasCancelled == true, "l'annullamento del task deve fermare la scansione")
        #expect(result.totalCount < 300)
        #expect(result.failureNotes.isEmpty == false || result.statistics.errorCount == 0)
    }

    @Test func multiFolderScanMergesResults() async {
        let first = TestPaths.mkdir("Prima", in: root)
        let second = TestPaths.mkdir("Seconda", in: root)
        TestPaths.touch("solo-prima.jpg", in: first)
        TestPaths.touch("solo-seconda.mp4", in: second)

        let result = await FileScanner.scan(
            folders: [FolderRef(url: first, displayName: "Prima"), FolderRef(url: second, displayName: "Seconda")],
            recursive: true,
            ruleBook: book
        )

        #expect(result.totalCount == 2)
        #expect(result.folders.count == 2)
    }
}
