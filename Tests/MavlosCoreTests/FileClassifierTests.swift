import Testing
import MavlosCore

@Suite
struct FileClassifierTests {

    private let ruleBook = RuleBook()

    // MARK: Catalogo estensioni

    @Test func knownExtensionsMapToExpectedCategories() {
        #expect(FileCategory(fileExtension: "pdf") == .documents)
        #expect(FileCategory(fileExtension: "DOCX") == .documents)
        #expect(FileCategory(fileExtension: "jpg") == .images)
        #expect(FileCategory(fileExtension: ".png") == .images)
        #expect(FileCategory(fileExtension: "mp3") == .music)
        #expect(FileCategory(fileExtension: "mov") == .video)
        #expect(FileCategory(fileExtension: "zip") == .archives)
        #expect(FileCategory(fileExtension: "qqqq") == nil, "estensione sconosciuta: nessuna categoria inventata")
    }

    @Test func normalizationTrimsDotsAndSpaces() {
        #expect(FileCategory.normalized(" .PKG ") == "pkg")
        #expect(FileCategory.normalized("MD") == "md")
    }

    // MARK: Regole personalizzate

    @Test func customRuleTakesPrecedenceOverKnownExtension() {
        let destination = TestPaths.tempRoot().appendingPathComponent("Fatture", isDirectory: true)
        defer { TestPaths.remove(destination.deletingLastPathComponent()) }
        let rule = OrganizationRule(
            name: "Fatture",
            extensions: Set(["pdf", "docx"]),
            destination: destination,
            category: .documents,
            priority: 10,
            isActive: true
        )
        let book = RuleBook(customRules: [rule])

        let result = book.classify(name: "gennaio.pdf", fileExtension: "pdf")
        #expect(result.category == .documents)
        #expect(result.destination == destination)
        #expect(result.ruleName == "Fatture")
        #expect(result.status == .classified)
    }

    @Test func inactiveRuleIsIgnored() {
        let destination = TestPaths.tempRoot().appendingPathComponent("Altro", isDirectory: true)
        let rule = OrganizationRule(
            name: "Ripostiglio",
            extensions: Set(["txt"]),
            destination: destination,
            category: .others,
            priority: 99,
            isActive: false
        )
        let book = RuleBook(customRules: [rule])

        let result = book.classify(name: "appunto.txt", fileExtension: "txt")
        #expect(result.destination != destination)
        #expect(result.ruleName != "Ripostiglio")
    }

    @Test func higherPriorityRuleWins() {
        let root = TestPaths.tempRoot()
        defer { TestPaths.remove(root) }
        let first = root.appendingPathComponent("Uno", isDirectory: true)
        let second = root.appendingPathComponent("Due", isDirectory: true)
        let low = OrganizationRule(name: "Bassa", extensions: Set(["csv"]), destination: first,
                                   category: .documents, priority: 1, isActive: true)
        let high = OrganizationRule(name: "Alta", extensions: Set(["csv"]), destination: second,
                                    category: .archives, priority: 5, isActive: true)
        let book = RuleBook(customRules: [low, high, low])

        let result = book.classify(name: "dati.csv", fileExtension: "csv")
        #expect(result.destination == second)
    }

    // MARK: Fallback e da-verificare

    @Test func unknownExtensionGoesToNeedsReviewAsOthers() {
        let result = ruleBook.classify(name: "binario.zx8", fileExtension: "zx8")
        #expect(result.category == .others)
        #expect(result.destination == nil)
        #expect(result.status == .needsReview)
        #expect(result.ruleName == "da verificare")
    }

    @Test func documentHintFromFileName() {
        let result = ruleBook.classify(name: "fattura-gennaio.zx8", fileExtension: "zx8")
        #expect(result.hint == "Sembra un documento di lavoro.")
        let plain = ruleBook.classify(name: "casa1234.zx8", fileExtension: "zx8")
        #expect(plain.hint == nil)
    }

    @Test func screenshotHintFromFileName() {
        let result = ruleBook.classify(name: "schermata-2026-10-30.zx8", fileExtension: "zx8")
        #expect(result.hint != nil)
        #expect(result.hint!.isEmpty == false)
    }

    @Test func emptyExtensionGoesToNeedsReview() {
        let result = ruleBook.classify(name: "estensione-mancante", fileExtension: "")
        #expect(result.category == .others)
        #expect(result.status == .needsReview)
    }

    // MARK: Destinazioni di sistema

    @Test func defaultDestinationsResolveInsideHome() {
        let home = PathDefaults.homeDirectory().standardizedFileURL.path
        let images = FileCategory.images.defaultDestinationURL()?.standardizedFileURL.path ?? ""
        #expect(images.hasPrefix(home), "la destinazione deve restare nell'utente")
        #expect(FileCategory.others.defaultDestinationURL() == nil)
    }
}
