import SwiftUI
import AppKit
import Combine
import MavlosCore

/// Canale Sendable per inoltrare dal thread di scansione al MainActor gli
/// snapshot di avanzamento: incapsula la weak reference al destinatario così
/// che le closure `@Sendable` dei servizi non catturino direttamente `AppState`
/// (che non è Sendable). Il metodo del relay gira su un thread qualsiasi e
/// ripubblica sul MainActor.
private final class ProgressRelay: @unchecked Sendable {

    private weak var owner: AppState?

    init(owner: AppState) {
        self.owner = owner
    }

    func publishScanProgress(_ snapshot: ScanProgressSnapshot) {
        Task { @MainActor [weak self] in
            self?.owner?.progress = snapshot
        }
    }

    func publishOrganizationProgress(_ snapshot: MoveProgress) {
        Task { @MainActor [weak self] in
            self?.owner?.organizationProgress = snapshot
        }
    }
}

/// Stato centrale e condiviso dell'app: navigazione, selezione cartelle,
/// pipeline di scansione, anteprima operazioni, organizzazione e annullamenti.
/// I servizi con accesso ai dischi girano su task detached; le letture UI
/// avvengono sempre sul MainActor.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Tipi

    enum Page: String, CaseIterable, Identifiable {
        case home, scan, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return L.s("Home")
            case .scan: return L.s("Scansione")
            case .settings: return L.s("Impostazioni")
            }
        }

        var systemImage: String {
            switch self {
            case .home: return "house"
            case .scan: return "viewfinder"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    enum ScanStage: Equatable {
        case folderSelection
        case progress
        case results
        case review
    }

    enum ReviewMode: Equatable {
        case batch
        case single
    }

    struct Toast: Equatable {
        let message: String
        let isError: Bool
    }

    // MARK: - Stato pubblicato

    @Published var page: Page = .home
    @Published var scanStage: ScanStage = .folderSelection

    // Selezione delle cartelle da scansionare
    @Published var customFolders: [FolderRef] = []
    @Published var selectedFolderIDs: Set<UUID> = []

    // Scansione
    @Published var isScanning = false
    @Published var progress = ScanProgressSnapshot.initial
    @Published var scanResult: ScanResult?

    // Revisione e organizzazione
    var reviewMode: ReviewMode = .batch
    @Published var proposals: [MoveProposal] = []
    @Published var organizing = false
    @Published var organizationProgress = MoveProgress(completed: 0, total: 0, currentFile: nil)
    @Published var organizationRun: OrganizationRun?
    @Published var showConfirmation = false

    // Scansione pianificata pronta per la revisione
    @Published var pendingScheduledResult: ScanResult?

    // Feedback immediato
    @Published var toast: Toast?

    // MARK: - Servizi

    let settings = SettingsStore()
    let journal = OperationJournal()
    private var scanTask: Task<Void, Never>?
    private var scheduledScanRunning = false

    private var selectionSnapshot: Set<UUID> = []
    private var selectionOriginPage: Page? = nil

    // Identificativi stabili delle cartelle di sistema mostrate in lista
    private static let downloadsID = UUID(uuidString: "C7AD41C8-0000-4A68-B5A4-000000000001")!
    private static let desktopID = UUID(uuidString: "C7AD41C8-0000-4A68-B5A4-000000000002")!
    private static let documentsID = UUID(uuidString: "C7AD41C8-0000-4A68-B5A4-000000000003")!

    // MARK: - Cartelle

    var specialFolders: [FolderRef] {
        var refs: [FolderRef] = []
        if let downloads = PathDefaults.downloadsURL() {
            refs.append(FolderRef(url: downloads, displayName: "Download", securityScoped: false, id: Self.downloadsID))
        }
        if let desktop = PathDefaults.desktopURL() {
            refs.append(FolderRef(url: desktop, displayName: "Scrivania", securityScoped: false, id: Self.desktopID))
        }
        if let documents = PathDefaults.documentsURL() {
            refs.append(FolderRef(url: documents, displayName: "Documenti", securityScoped: false, id: Self.documentsID))
        }
        return refs
    }

    var folderOptions: [FolderRef] { specialFolders + customFolders }

    var selectedFolderRefs: [FolderRef] {
        folderOptions.filter { selectedFolderIDs.contains($0.id) }
    }

    var defaultFolderRef: FolderRef? { settings.defaultFolderRef() }

    /// Cartella predefinita usata o segnalata su Home.
    var defaultManifestPath: String {
        defaultFolderRef.map { PathDefaults.displayPath($0.url) } ?? L.s("Nessuna cartella selezionata")
    }

    var undoAvailable: Bool { !journal.isEmpty }

    var selectedMoveCount: Int {
        proposals.filter { $0.isSelected && $0.isEligible }.count
    }

    var currentSingleProposal: MoveProposal? {
        guard singleIndex >= 0, singleIndex < proposals.count else { return nil }
        return proposals[singleIndex]
    }

    var singleIndex = 0

    // MARK: - Avvio

    func bootstrap() async {
        restoreCustomFolders()
        restoreSelectionDefaults()

        // Prima apertura: ~/Downloads è la cartella predefinita.
        if defaultFolderRef == nil, let downloads = PathDefaults.downloadsURL() {
            setDefaultFolder(FolderRef(url: downloads, displayName: "Download"))
        }

        await checkScheduledScan()
    }

    private func restoreCustomFolders() {
        var restored: [FolderRef] = []
        var seen = Set<String>()

        // 1. Security-Scoped Bookmarks: cartelle autorizzate con il selettore nativo.
        for url in BookmarkService.resolvedFolders() {
            let key = url.standardizedFileURL.path
            guard !seen.contains(key), !isSpecialPath(key) else { continue }
            seen.insert(key)
            restored.append(
                FolderRef(url: url, displayName: url.lastPathComponent, securityScoped: true)
            )
        }

        // 2. Cartelle selezionate nelle ultime finestre di lavoro.
        for path in settings.preferences.lastSelectionPaths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            let key = url.standardizedFileURL.path
            guard !seen.contains(key), !isSpecialPath(key) else { continue }
            guard PermissionManager.accessibility(of: url) != .missing else { continue }
            seen.insert(key)
            restored.append(FolderRef(url: url, displayName: url.lastPathComponent))
        }

        customFolders = restored
    }

    private func restoreSelectionDefaults() {
        var selection = Set<UUID>()

        // Percorsi dell'ultima selezione effettuata.
        if !settings.preferences.lastSelectionPaths.isEmpty {
            let lastPaths = Set(settings.preferences.lastSelectionPaths)
            for ref in folderOptions where lastPaths.contains(ref.url.standardizedFileURL.path) {
                selection.insert(ref.id)
            }
        }

        // Download resta comunque predefinita e selezionata.
        if let downloads = specialFolders.first(where: { $0.url.standardizedFileURL.path == PathDefaults.downloadsURL()?.standardizedFileURL.path }) {
            selection.insert(downloads.id)
        }

        selectedFolderIDs = selection
    }

    private func isSpecialPath(_ standardizedPath: String) -> Bool {
        specialFolders.contains { $0.url.standardizedFileURL.path == standardizedPath }
    }

    // MARK: - Cartella predefinita

    func setDefaultFolder(_ ref: FolderRef) {
        guard PermissionManager.accessibility(of: ref.url) == .accessible else {
            showToast(L.s("Cartella non accessibile"), isError: true)
            return
        }
        settings.update {
            $0.defaultFolderPath = ref.url.standardizedFileURL.path
            $0.defaultFolderDisplayName = ref.displayName
            $0.defaultFolderIsSecurityScoped = ref.securityScoped
        }
        if ref.securityScoped {
            BookmarkService.saveBookmark(for: ref.url)
        }
    }

    /// "Cambia" in Impostazioni: imposta la cartella predefinita dal selettore.
    func setDefaultFromPanel(_ url: URL) {
        addCustomFolder(from: [url])
        let ref = FolderRef(
            url: url,
            displayName: url.standardizedFileURL.lastPathComponent,
            securityScoped: true
        )
        setDefaultFolder(ref)
    }

    // MARK: - Selettore nativo

    func chooseFolder(allowMultiple: Bool = true, message: String) async -> [URL] {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = allowMultiple
            panel.canCreateDirectories = true
            panel.directoryURL = defaultFolderRef?.url ?? PathDefaults.downloadsURL() ?? PathDefaults.homeDirectory()
            panel.message = message
            panel.begin { response in
                let urls = (response == .OK) ? panel.urls : []
                continuation.resume(returning: urls)
            }
        }
    }

    /// "Altra cartella" su Home: imposta la cartella predefinita.
    func setAnotherHomeFolder(_ urls: [URL]) {
        guard let url = urls.first else { return }
        let ref = FolderRef(
            url: url,
            displayName: url.standardizedFileURL.lastPathComponent,
            securityScoped: true
        )
        addCustomFolder(from: [url])
        setDefaultFolder(ref)
        openFolderSelection(from: .home)
    }

    /// "Altra cartella…" nella schermata di selezione multipla.
    func addCustomFolder(from urls: [URL]) {
        for url in urls {
            let key = url.standardizedFileURL.path

            if let existing = folderOptions.first(where: { $0.url.standardizedFileURL.path == key }) {
                selectedFolderIDs.insert(existing.id)
                continue
            }

            guard PermissionManager.accessibility(of: url) != .missing,
                  !isSpecialPath(key)
            else { continue }

            BookmarkService.saveBookmark(for: url)
            let ref = FolderRef(url: url, displayName: key.split(separator: "/").last.map(String.init) ?? url.lastPathComponent, securityScoped: true)
            customFolders.append(ref)
            selectedFolderIDs.insert(ref.id)
        }
        rememberSelection(selectedFolderRefs)
    }

    private func rememberSelection(_ refs: [FolderRef]) {
        let paths = refs.map { $0.url.standardizedFileURL.path }
        settings.update { $0.lastSelectionPaths = paths }
    }

    func toggleFolder(_ ref: FolderRef) {
        if selectedFolderIDs.contains(ref.id) {
            selectedFolderIDs.remove(ref.id)
        } else {
            selectedFolderIDs.insert(ref.id)
        }
        rememberSelection(selectedFolderRefs)
    }

    /// Apre la schermata di selezione salvando lo stato corrente (per "Annulla").
    func openFolderSelection(from origin: Page? = nil) {
        selectionSnapshot = selectedFolderIDs
        selectionOriginPage = origin ?? page
        page = .scan
        scanStage = .folderSelection
    }

    func cancelFolderSelection() {
        selectedFolderIDs = selectionSnapshot
        page = selectionOriginPage ?? .home
    }

    // MARK: - Scansione

    func scanDefaultFolder() {
        guard let ref = defaultFolderRef else {
            showToast(L.s("Nessuna cartella predefinita disponibile"), isError: true)
            return
        }
        guard PermissionManager.accessibility(of: ref.url) == .accessible else {
            showToast(L.formatted("Permessi insufficienti per leggere «%@»", ref.displayName), isError: true)
            return
        }
        startScan(folders: [ref])
    }

    func startScanForSelection() {
        let refs = selectedFolderRefs
        guard !refs.isEmpty else {
            showToast(L.s("Seleziona almeno una cartella"), isError: true)
            return
        }
        let accessible = refs.filter { PermissionManager.accessibility(of: $0.url) == .accessible }
        guard !accessible.isEmpty else {
            showToast(L.s("Le cartelle scelte non sono accessibili"), isError: true)
            return
        }
        rememberSelection(accessible)
        startScan(folders: accessible)
    }

    private func startScan(folders: [FolderRef]) {
        guard !isScanning else { return }

        isScanning = true
        progress = ScanProgressSnapshot(phase: .scanning)
        organizationRun = nil
        organizationProgress = MoveProgress(completed: 0, total: 0, currentFile: nil)
        pendingScheduledResult = nil
        page = .scan
        scanStage = .progress

        let folderSnapshot = folders
        let recursive = settings.preferences.recursiveScanning
        let ruleBook = settings.effectiveRuleBook()
        let progressRelay = ProgressRelay(owner: self)

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = await FileScanner.scan(
                folders: folderSnapshot,
                recursive: recursive,
                ruleBook: ruleBook,
                progress: { snapshot in
                    // Aggiornamento UI dal thread di scansione, un hop sul MainActor.
                    progressRelay.publishScanProgress(snapshot)
                }
            )
            guard let self = self else { return }
            await self.finishScan(result)
        }
    }

    private func finishScan(_ result: ScanResult) {
        isScanning = false
        scanTask = nil
        scanResult = result
        settings.update { $0.lastAutomaticScan = Date() }
        rebuildProposals(from: result)
        scanStage = .results

        Task {
            if settings.preferences.notifyOnScanComplete && !result.wasCancelled {
                let authorized = await NotificationService.requestAuthorizationIfNeeded()
                if authorized {
                    await NotificationService.notifyScanCompleted(
                        count: result.totalCount,
                        folderName: result.folders.map(\.displayName).joined(separator: " · ")
                    )
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func rebuildProposals(from result: ScanResult) {
        proposals = FileOrganizer.proposals(
            for: result.files,
            policy: settings.preferences.duplicatePolicy
        )
    }

    // MARK: - Scansione pianificata

    /// Se è ora, esegue la scansione pianificata in background e prepara un
    /// esito da rivedere. Non sposta mai file: solo raccolta risultati.
    func checkScheduledScan() async {
        guard settings.preferences.automaticScan != .off else { return }
        guard settings.isAutomaticScanDue() else { return }
        guard !isScanning, !scheduledScanRunning else { return }
        guard let defaultRef = defaultFolderRef,
              PermissionManager.accessibility(of: defaultRef.url) == .accessible
        else { return }

        scheduledScanRunning = true
        defer { scheduledScanRunning = false }

        let folders = [defaultRef]
        let recursive = settings.preferences.recursiveScanning
        let ruleBook = settings.effectiveRuleBook()

        let result = await Task.detached(priority: .background) {
            await FileScanner.scan(folders: folders, recursive: recursive, ruleBook: ruleBook)
        }.value

        settings.update { $0.lastAutomaticScan = Date() }
        guard result.totalCount > 0, scanResult == nil else { return }

        pendingScheduledResult = result

        if settings.preferences.notifyOnScanComplete {
            let authorized = await NotificationService.requestAuthorizationIfNeeded()
            if authorized {
                await NotificationService.notifyScanCompleted(
                    count: result.totalCount,
                    folderName: defaultRef.displayName
                )
            }
        }
    }

    func adoptScheduledResult() {
        guard let pending = pendingScheduledResult else { return }
        pendingScheduledResult = nil
        scanResult = pending
        rebuildProposals(from: pending)
        page = .scan
        scanStage = .results
    }

    func dismissScheduledResult() {
        pendingScheduledResult = nil
    }

    // MARK: - Anteprima e organizzazione

    func beginReview(mode: ReviewMode) {
        guard proposals.contains(where: { $0.isEligible }) else {
            showToast(L.s("Nessuna operazione da rivedere"), isError: true)
            return
        }
        reviewMode = mode
        singleIndex = proposals.firstIndex(where: { $0.isSelected && $0.isEligible }) ?? 0
        organizationRun = nil
        organizationProgress = MoveProgress(completed: 0, total: selectedMoveCount, currentFile: nil)
        page = .scan
        scanStage = .review
    }

    func exitReview(to stage: ScanStage = .results) {
        page = .scan
        scanStage = stage
    }

    func completeReview() {
        organizationRun = nil
        proposals = []
        scanResult = nil
        pendingScheduledResult = nil
        singleIndex = 0
        scanStage = .folderSelection
        page = .home
    }

    func requestOrganize() {
        guard selectedMoveCount > 0 else {
            showToast(L.s("Seleziona i file da spostare"), isError: true)
            return
        }
        if settings.preferences.askBeforeMoving {
            showConfirmation = true
        } else {
            Task { await runOrganization() }
        }
    }

    /// Esegue le proposte selezionate una alla volta. Un fallimento non
    /// interrompe le operazioni rimanenti.
    func runOrganization() async {
        guard !organizing else { return }
        let pending = proposals.filter { $0.isSelected && $0.isEligible }
        guard !pending.isEmpty else { return }

        organizing = true
        showConfirmation = false
        organizationProgress = MoveProgress(completed: 0, total: pending.count, currentFile: nil)

        // Preflight (sul main, dove le richieste TCC si possono mostrare in
        // primo piano): ogni destinazione unica deve essere creabile e
        // scrivibile, altrimenti non ha senso partire e fallire tutto.
        let destinations = Set(pending.compactMap { $0.item.destinationURL?.standardizedFileURL })
        do {
            for destination in destinations {
                try PermissionManager.verifyWritable(destination)
            }
        } catch {
            organizing = false
            showToast(L.s("Spostamento non avviato") + " · " + error.localizedDescription, isError: true)
            organizationProgress = MoveProgress(completed: 0, total: 0, currentFile: nil)
            return
        }

        let journalRef = journal
        let progressRelay = ProgressRelay(owner: self)
        let run = await Task.detached(priority: .userInitiated) {
            await OrganizationService.organize(
                proposals: pending,
                journal: journalRef,
                progress: { snapshot in
                    // Aggiornamento UI dal thread di organizzazione, un hop sul MainActor.
                    progressRelay.publishOrganizationProgress(snapshot)
                }
            )
        }.value

        organizing = false
        organizationRun = run

        let movedIDs = Set(run.results.filter { $0.outcome == .moved }.map { $0.proposalID })
        proposals = proposals.filter { !movedIDs.contains($0.id) }
        FileOrganizer.rebuildBatchCollisions(&proposals)

        // I motivi delle operazioni fallite restano visibili sulla riga della
        // proposta: niente errori muti.
        for result in run.results where result.outcome == .failed {
            if let index = proposals.firstIndex(where: { $0.id == result.proposalID }) {
                proposals[index].note = result.message
            }
        }

        var message = L.formatted("Spostati %d file", run.movedCount)
        if run.failedCount > 0 {
            message += L.formatted(" · %d non riusciti", run.failedCount)
            if let firstFailure = run.results.first(where: { $0.outcome == .failed }),
               let reason = firstFailure.message {
                message += " — " + reason
            }
        }
        showToast(message, isError: run.movedCount == 0)
    }

    // MARK: - Operazioni avanzate nel flusso "uno a uno"

    func skipSingle() {
        advanceSingle(from: singleIndex + 1)
    }

    func moveCurrentSingle(_ proposal: MoveProposal) {
        guard let index = proposals.firstIndex(where: { $0.id == proposal.id }) else { return }
        Task {
            let targeted = proposals[index]
            let journalRef = journal
            let result = await Task.detached(priority: .userInitiated) {
                FileMover.move(targeted, journal: journalRef)
            }.value

            if result.outcome == .moved {
                proposals.remove(at: index)
            } else {
                proposals[index].note = result.message
            }

            showToast(
                result.message ?? L.formatted("«%@» spostato", targeted.fileName),
                isError: result.outcome == .failed
            )
            advanceSingle(from: index)
        }
    }

    /// Sposta immediatamente un solo file (voce "Sposta solo questo file").
    func organizeSingleNow(_ proposalID: UUID) {
        guard let index = proposals.firstIndex(where: { $0.id == proposalID }) else { return }
        Task {
            let targeted = proposals[index]
            let journalRef = journal
            let result = await Task.detached(priority: .userInitiated) {
                FileMover.move(targeted, journal: journalRef)
            }.value

            if result.outcome == .moved {
                proposals.remove(at: index)
            } else {
                proposals[index].note = result.message
            }

            showToast(
                result.message ?? L.formatted("«%@» spostato", targeted.fileName),
                isError: result.outcome == .failed
            )
        }
    }

    private func advanceSingle(from index: Int) {
        guard !proposals.isEmpty else {
            singleIndex = 0
            return
        }
        var cursor = max(0, index)
        while cursor < proposals.count, !proposals[cursor].isEligible {
            cursor += 1
        }
        singleIndex = min(cursor, max(0, proposals.count - 1))
    }

    // MARK: - Selezione delle proposte

    func toggleProposal(_ id: UUID) {
        guard let index = proposals.firstIndex(where: { $0.id == id }) else { return }
        let proposal = proposals[index]
        if proposal.isSelected {
            proposals[index].isSelected = false
        } else if proposal.isEligible {
            proposals[index].isSelected = true
        }
    }

    func selectAllEligible() {
        for index in proposals.indices where proposals[index].isEligible {
            proposals[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in proposals.indices {
            proposals[index].isSelected = false
        }
    }

    func excludeSelection() {
        for index in proposals.indices where proposals[index].isSelected {
            proposals[index].isSelected = false
        }
    }

    /// Cambia categoria ad un insieme di file e ricalcola destinazioni.
    func changeCategory(_ category: FileCategory, forIDs ids: [UUID]) {
        let idSet = Set(ids)
        for index in proposals.indices where idSet.contains(proposals[index].id) {
            let destination = category.defaultDestinationURL()
            proposals[index].item.category = category
            proposals[index].item.destinationURL = destination
            proposals[index].item.ruleName = "modificata dall'utente"
            proposals[index].item.status = (destination != nil) ? .classified : .needsReview

            FileOrganizer.refresh(&proposals[index])
            if !proposals[index].isEligible {
                proposals[index].isSelected = false
            }
        }
    }

    /// Imposta una destinazione alternativa scelta dal Finder.
    func setDestination(_ url: URL, forIDs ids: [UUID]) {
        let idSet = Set(ids)
        for index in proposals.indices where idSet.contains(proposals[index].id) {
            proposals[index].item.destinationURL = url
            proposals[index].item.ruleName = "destinazione scelta"
            proposals[index].item.status = .classified
            FileOrganizer.refresh(&proposals[index])
            if !proposals[index].isEligible {
                proposals[index].isSelected = false
            }
        }
    }

    func setConflictPolicy(_ policy: ConflictPolicy, forIDs ids: [UUID]) {
        let idSet = Set(ids)
        for index in proposals.indices where idSet.contains(proposals[index].id) {
            proposals[index].policy = policy
        }
    }

    // MARK: - Annulla ultima operazione

    func undoLastOperation() {
        guard let last = journal.allRecords().last else {
            showToast(L.s("Nessuna operazione da annullare"), isError: true)
            return
        }
        Task {
            let target = last
            let outcome = await Task.detached(priority: .utility) {
                FileMover.undo(target)
            }.value

            if outcome.success {
                journal.remove(recordID: target.id)
            }
            showToast(outcome.message, isError: !outcome.success)
        }
    }

    // MARK: - Toast

    func showToast(_ message: String, isError: Bool) {
        toast = Toast(message: message, isError: isError)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                if self.toast?.message == message {
                    self.toast = nil
                }
            }
        }
    }
}
