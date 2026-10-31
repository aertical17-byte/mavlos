import Foundation

/// Motore di scansione del filesystem con le API native di macOS e Swift
/// Concurrency. La scansione è annullabile, non segue link simbolici,
/// esclude pacchetti applicativi, file nascosti e cartelle protette.
public enum FileScanner {

    /// Cartelle mai analizzate (sistema, librerie interne).
    private static let protectedTopLevelNames: Set<String> = [
        "Library", "System", "Volumes", "Applications", "dev", "opt",
        "private", "usr", "bin", "sbin", "etc", "cores", "home", "net"
    ]
    private static let maxDepth = 64
    private static let progressInterval: TimeInterval = 0.08

    // MARK: - API

    /// Scansiona le cartelle indicate e classifica i file con il libro di regole.
    /// - Returns: risultato anche in caso di annullamento (con esito parziale).
    public static func scan(
        folders: [FolderRef],
        recursive: Bool,
        ruleBook: RuleBook,
        progress: (@Sendable (ScanProgressSnapshot) -> Void)? = nil
    ) async -> ScanResult {
        let startedAt = Date()
        var statistics = ScanStatistics()
        var notes: [String] = []
        var files: [FileItem] = []
        var snapshot = ScanProgressSnapshot(phase: .scanning)
        var lastEmission = Date.distantPast
        var cancelled = false

        func emit(_ phase: ScanPhase, currentFolder: String?) {
            let now = Date()
            let phaseChanged = phase != snapshot.phase
            guard phaseChanged || now.timeIntervalSince(lastEmission) >= progressInterval else { return }
            lastEmission = now
            let snap = ScanProgressSnapshot(
                phase: phase,
                found: files.count,
                analyzed: statistics.analyzedCount,
                classified: statistics.classifiedCount,
                currentFolder: currentFolder
            )
            snapshot = snap
            progress?(snap)
        }

        outer: for ref in folders {
            // Accesso security-scoped per le cartelle consentite dal selettore.
            var unlocked = false
            if ref.securityScoped {
                unlocked = ref.url.startAccessingSecurityScopedResource()
            }
            defer { if unlocked { ref.url.stopAccessingSecurityScopedResource() } }

            switch PermissionManager.accessibility(of: ref.url) {
            case .missing:
                notes.append("«\(ref.displayName)» non esiste più.")
                continue
            case .restricted:
                notes.append("Permessi insufficienti per leggere «\(ref.displayName)». Concedi l'accesso o scegli di nuovo la cartella dal Finder.")
                continue
            case .accessible:
                break
            }

            if isProtectedSelection(ref.url) {
                notes.append("«\(ref.displayName)» è una cartella protetta di sistema e non viene analizzata.")
                continue
            }

            // Attraversamento in ampiezza: le sottocartelle analizzate solo
            // con l'opzione ricorsiva.
            var queue: [(directory: URL, depth: Int)] = [(ref.url.standardizedFileURL, 0)]
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isHiddenKey,
                .fileSizeKey, .creationDateKey, .contentModificationDateKey
            ]
            let keyArray = Array(resourceKeys)

            while !queue.isEmpty {
                let entry = queue.removeFirst()
                let directory = entry.directory
                let depth = entry.depth

                guard !Task.isCancelled else { cancelled = true; break outer }

                emit(.scanning, currentFolder: directory.lastPathComponent)

                let children: [URL]
                do {
                    children = try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: keyArray,
                        options: []
                    )
                } catch {
                    notes.append("Impossibile leggere «\(PathDefaults.compactPath(directory))».")
                    statistics.errorCount += 1
                    continue
                }

                for child in children {
                    guard !Task.isCancelled else { cancelled = true; break outer }

                    let name = child.lastPathComponent
                    let values = try? child.resourceValues(forKeys: resourceKeys)

                    // File e cartelle nascosti: mai toccati.
                    if name.hasPrefix(".") || values?.isHidden == true {
                        statistics.skippedCount += 1
                        continue
                    }
                    // Link simbolici: mai seguiti (niente cicli, niente indesiderati).
                    if values?.isSymbolicLink == true {
                        statistics.skippedCount += 1
                        continue
                    }

                    let isDirectory = values?.isDirectory ?? child.hasDirectoryPath
                    guard !isDirectory else {
                        if values?.isPackage == true {
                            // Pacchetti applicativi e bundle: esclusi dall'organizzazione.
                            statistics.skippedCount += 1
                        } else if recursive && depth < maxDepth {
                            queue.append((child, depth + 1))
                        } else {
                            statistics.skippedCount += 1
                        }
                        continue
                    }

                    // File regolare: attributi reali + classificazione.
                    statistics.analyzedCount += 1
                    let classification = ruleBook.classify(name: name, fileExtension: child.pathExtension)
                    let item = FileItem(
                        url: child,
                        pathExtension: child.pathExtension,
                        size: Int64(values?.fileSize ?? 0),
                        creationDate: values?.creationDate,
                        modificationDate: values?.contentModificationDate,
                        category: classification.category,
                        destinationURL: classification.destination,
                        ruleName: classification.ruleName,
                        status: classification.status,
                        hint: classification.hint
                    )
                    files.append(item)
                    if classification.status == .classified {
                        statistics.classifiedCount += 1
                    }
                    emit(.scanning, currentFolder: directory.lastPathComponent)
                }
            }
        }

        cancelled = cancelled || Task.isCancelled
        let finishedAt = Date()
        emit(cancelled ? ScanPhase.cancelled : ScanPhase.completed, currentFolder: nil)

        return ScanResult(
            folders: folders,
            startedAt: startedAt,
            finishedAt: finishedAt,
            recursive: recursive,
            wasCancelled: cancelled,
            statistics: statistics,
            failureNotes: notes,
            files: files
        )
    }

    // MARK: - Sicurezza

    /// Rifiuta esplicitamente librerie e sorgenti di sistema.
    private static func isProtectedSelection(_ url: URL) -> Bool {
        let name = url.standardizedFileURL.lastPathComponent
        if name.hasPrefix(".") { return true }
        return protectedTopLevelNames.contains(name)
    }
}
