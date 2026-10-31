import Testing
import Foundation
import MavlosCore

@Suite
struct FormattingAndPathsTests {

    // MARK: Formattazione numerica (locale italiana)

    @Test func fileCountUsesItalianThousandsSeparator() {
        #expect(Formatting.fileCount(0) == "0")
        #expect(Formatting.fileCount(123) == "123")
        #expect(Formatting.fileCount(1248) == "1.248")
        #expect(Formatting.fileCount(31_048) == "31.048")
    }

    @Test func fileSizeBuckets() {
        #expect(Formatting.fileSize(0) == "1 KB")
        #expect(Formatting.fileSize(512) == "1 KB")
        #expect(Formatting.fileSize(1024) == "1 KB")
        #expect(Formatting.fileSize(2048) == "2 KB")
        #expect(Formatting.fileSize(1024 * 1024) == "1 MB")
        #expect(Formatting.fileSize(Int64(2) * 1024 * 1024) == "2 MB")
        #expect(Formatting.fileSize(Int64(2) * 1024 * 1024 * 1024) == "2 GB")
        #expect(Formatting.fileSize(Int64(3) * 1024 * 1024 * 1024) == "3 GB")
    }

    @Test func progressCount() {
        #expect(Formatting.progress(2412, 3108) == "2.412 di 3.108")
    }

    // MARK: Percorsi

    @Test func compactPathOutsideHomeIsUnchanged() {
        let temp = URL(fileURLWithPath: "/private/var/domenica.jpg", isDirectory: false)
        #expect(PathDefaults.compactPath(temp) == temp.path)
    }

    @Test func compactPathInsideHomeUsesTilde() {
        let home = PathDefaults.homeDirectory()
        #expect(PathDefaults.compactPath(home) == "~")
        let inside = home.appendingPathComponent("Download/prova.pdf")
        let compact = PathDefaults.compactPath(inside)
        #expect(compact.hasPrefix("~/"))
        #expect(compact.hasSuffix("Download/prova.pdf"))
    }

    @Test func isInsideResolution() {
        let parent = TestPaths.tempRoot()
        defer { TestPaths.remove(parent) }
        let nested = TestPaths.mkdir("Sotto", in: parent)
        let file = TestPaths.touch("documento.pdf", in: nested)

        #expect(PathDefaults.isInside(file, of: parent) == true)
        #expect(PathDefaults.isInside(nested, of: parent) == true)
        #expect(PathDefaults.isInside(parent, of: parent) == false)
        #expect(PathDefaults.isInside(parent, of: nested) == false)
    }

    @Test func displayPathFallsBackToCompactForAbsolutePaths() {
        let temp = TestPaths.tempRoot().appendingPathComponent("dove/zia.md")
        #expect(PathDefaults.displayPath(temp) == PathDefaults.compactPath(temp))
    }
}
