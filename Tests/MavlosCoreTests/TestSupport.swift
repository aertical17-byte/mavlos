import Foundation
import MavlosCore

/// Utilità condivise: ogni test lavora solo dentro una cartella temporanea
/// dedicata e isolata, mai nelle cartelle reali dell'utente.
enum TestPaths {

    /// Cartella temporanea unica per un gruppo di test.
    static func tempRoot() -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("mavlos-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    static func mkdir(_ name: String, in parent: URL) -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    static func touch(_ name: String, in directory: URL, bytes: Data = Data("contenuto di prova".utf8)) -> URL {
        let url = directory.appendingPathComponent(name)
        try? bytes.write(to: url)
        return url
    }

    static func write(_ bytes: Data, to url: URL) {
        try? bytes.write(to: url, options: .atomic)
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

/// helper per costruire FileItem e proposte senza dipendere dal filesystem.
enum TestFixture {

    static func item(
        _ name: String,
        in folder: URL,
        destination: URL?,
        category: FileCategory = .documents,
        status: ClassificationStatus = .classified,
        size: Int64 = 128
    ) -> FileItem {
        FileItem(
            url: folder.appendingPathComponent(name),
            pathExtension: (name as NSString).pathExtension,
            size: size,
            creationDate: nil,
            modificationDate: nil,
            category: category,
            destinationURL: destination,
            ruleName: "test",
            status: status
        )
    }

    /// Proposta prodotta dall'organizzatore reale (l'inizializzatore è interno,
    /// quindi si passa da `FileOrganizer.proposals`).
    static func proposal(for item: FileItem, policy: ConflictPolicy = .keepBoth) -> MoveProposal {
        guard let proposal = FileOrganizer.proposals(for: [item], policy: policy).first else {
            fatalError("impossibile creare la proposta di test")
        }
        return proposal
    }
}
