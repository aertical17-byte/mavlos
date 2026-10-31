import Testing
import Foundation
import MavlosCore

@Suite
final class DuplicateDetectorTests {

    private var root: URL
    private var source: URL
    private var parking: URL

    init() {
        root = TestPaths.tempRoot()
        parking = TestPaths.mkdir("Partenza", in: root)
        source = TestPaths.touch("documento.pdf", in: parking, bytes: Data("contenuto A".utf8))
    }

    deinit {
        TestPaths.remove(root)
    }

    private func target(_ name: String, bytes: Data) -> URL {
        let area = TestPaths.mkdir("Arrivo", in: root)
        return TestPaths.touch(name, in: area, bytes: bytes)
    }

    // MARK: Rilevamento

    @Test func noConflictWhenTargetMissing() {
        let target = root.appendingPathComponent("assente.pdf", isDirectory: false)
        let detector = DuplicateDetector()
        #expect(detector.conflictKind(source: source, target: target) == .none)
    }

    @Test func nameOnlyWhenSameNameDifferentContent() {
        let target = target("documento.pdf", bytes: Data("contenuto B".utf8))
        let detector = DuplicateDetector()
        #expect(detector.conflictKind(source: source, target: target) == .nameOnly)
    }

    @Test func nameAndContentWhenIdentical() {
        let target = target("documento.pdf", bytes: Data("contenuto A".utf8))
        let detector = DuplicateDetector()
        #expect(detector.conflictKind(source: source, target: target) == .nameAndContent)
    }

    @Test func nameOnlyWhenSizesDiffer() {
        let target = target("documento.pdf", bytes: Data("contenuto A e ancora".utf8))
        let detector = DuplicateDetector()
        #expect(detector.conflictKind(source: source, target: target) == .nameOnly)
    }

    @Test func directoryTargetIsNotAConflict() {
        let directory = TestPaths.mkdir("cartella.pdf", in: root)
        let detector = DuplicateDetector()
        #expect(detector.conflictKind(source: source, target: directory) == .none)
    }

    // MARK: Nomi alternativi

    @Test func alternativeNameSequence() {
        TestPaths.touch("foto.png", in: root)
        TestPaths.touch("foto (2).png", in: root)
        let detector = DuplicateDetector()
        #expect(detector.alternativeName(for: "foto.png", avoidingAt: root) == "foto (3).png")
    }

    @Test func alternativeNameWithoutExtension() {
        TestPaths.touch("README", in: root)
        let detector = DuplicateDetector()
        #expect(detector.alternativeName(for: "README", avoidingAt: root) == "README (2)")
    }

    @Test func alternativeNameSkipsCaseInsensitiveMatches() {
        TestPaths.touch("report.TXT", in: root)
        try? Data("altro".utf8).write(to: root.appendingPathComponent("report.txt"))
        let detector = DuplicateDetector()
        #expect(detector.alternativeName(for: "report.txt", avoidingAt: root) == "report (2).txt")
    }

    @Test func timestampedNameKeepsExtension() {
        let name = DuplicateDetector.timestampedName("archivio.zip")
        #expect(name.hasPrefix("archivio-ripristino"))
        #expect(name.hasSuffix(".zip"))
    }
}
