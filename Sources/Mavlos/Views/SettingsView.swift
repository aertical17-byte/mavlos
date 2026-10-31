import SwiftUI
import AppKit
import MavlosCore

/// Schermata Impostazioni, su due colonne: Cartelle/Comportamento a sinistra,
/// Regole a destra (riferimento: screenshot 2).
struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    @State private var ruleEditorContext: RuleEditorContext?
    @State private var ruleToDelete: OrganizationRule?
    @State private var lastJournalEntry: OperationRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                HStack(alignment: .top, spacing: 30) {
                    leftColumn
                    rightColumn
                }
                .frame(maxWidth: 1020, alignment: .topLeading)
            }

            Text("mavlos 1.0 · macOS")
                .font(Typefaces.footerMono)
                .foregroundStyle(Palette.primaryText.opacity(0.34))
        }
        .padding(.horizontal, 40)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $ruleEditorContext) { context in
            RuleEditorSheet(existing: context.existing)
                .environmentObject(state)
        }
        .alert(
            L.s("Eliminare la regola?"),
            isPresented: Binding(
                get: { ruleToDelete != nil },
                set: { value in if !value { ruleToDelete = nil } }
            )
        ) {
            Button(L.s("Elimina"), role: .destructive) {
                if let rule = ruleToDelete {
                    state.settings.update {
                        $0.customRules.removeAll { $0.id == rule.id }
                    }
                }
                ruleToDelete = nil
            }
            Button(L.s("Annulla"), role: .cancel) {
                ruleToDelete = nil
            }
        } message: {
            Text(L.s("La regola personalizzata non sarà più applicata."))
        }
        .onAppear { refreshJournalEntry() }
        .onChange(of: state.toast) { _ in
            refreshJournalEntry()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.s("Impostazioni"))
                    .font(Typefaces.pageTitle)
                    .foregroundStyle(Palette.primaryText)
                Text(L.s("Scegli come lavora Mavlos."))
                    .font(Typefaces.bodyText)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            MascotBadge(size: 46)
        }
    }

    // MARK: - Colonna sinistra

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("cartelle")

            folderCard

            SectionLabel("comportamento")
                .padding(.top, 14)

            behaviorCard
        }
        .frame(maxWidth: 430, alignment: .topLeading)
    }

    private var folderCard: some View {
        VStack(spacing: 0) {
            defaultFolderRow
            rowSeparator
            recursiveRow
            rowSeparator
            autoScanRow
        }
        .card(radius: 14)
        .padding(.bottom, 4)
    }

    private var behaviorCard: some View {
        VStack(spacing: 0) {
            askConfirmationRow
            rowSeparator
            duplicateRow
            rowSeparator
            notificationRow
        }
        .card(radius: 14)
    }

    private var defaultFolderRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.s("Cartella predefinita"))
                    .font(Typefaces.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                MonoValue(state.defaultManifestPath, size: 11.5)
            }
            Spacer()
            ActionButton(
                kind: .secondary,
                title: L.s("Cambia"),
                icon: "chevron.down",
                action: {
                    Task {
                        let urls = await state.chooseFolder(message: L.s("Imposta la cartella predefinita"))
                        if let url = urls.first {
                            state.setDefaultFromPanel(url)
                        }
                    }
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    private var recursiveRow: some View {
        settingsRow(
            title: L.s("Includi sottocartelle"),
            subtitle: L.s("scansione ricorsiva"),
            isOn: Binding(
                get: { state.settings.preferences.recursiveScanning },
                set: { value in state.settings.update { $0.recursiveScanning = value } }
            )
        )
    }

    private var autoScanRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.s("Scansione automatica"))
                    .font(Typefaces.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                Text(L.s("prepara i risultati in attesa d'approvazione"))
                    .font(Typefaces.mono(11))
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            autoScanMenu
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    private var autoScanMenu: some View {
        let frequency = state.settings.preferences.automaticScan

        return Menu {
            ForEach(AutoScanFrequency.allCases, id: \.self) { candidate in
                Button(candidate.displayName) {
                    state.settings.update { $0.automaticScan = candidate }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(frequency.displayName)
                    .font(Typefaces.mono(12, .medium))
                    .foregroundStyle(Palette.primaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var askConfirmationRow: some View {
        settingsRow(
            title: L.s("Chiedi conferma"),
            subtitle: L.s("prima di spostare i file"),
            isOn: Binding(
                get: { state.settings.preferences.askBeforeMoving },
                set: { value in state.settings.update { $0.askBeforeMoving = value } }
            )
        )
    }

    /// Preferenza di gestione dei duplicati, riformulata in modo sicuro:
    /// attiva = "mantieni entrambi i file rinominando"; disattiva = "salta".
    /// In entrambi i casi mai eliminazioni né sovrascritture.
    private var duplicateRow: some View {
        settingsRow(
            title: L.s("Rinomina duplicati"),
            subtitle: L.s("mantieni entrambi i file"),
            isOn: Binding(
                get: { state.settings.preferences.duplicatePolicy == .keepBoth },
                set: { value in state.settings.update { $0.duplicatePolicy = value ? .keepBoth : .skip } }
            )
        )
    }

    private var notificationRow: some View {
        settingsRow(
            title: L.s("Notifica a fine scansione"),
            subtitle: L.s("a ogni scansione completata"),
            isOn: Binding(
                get: { state.settings.preferences.notifyOnScanComplete },
                set: { value in state.settings.update { $0.notifyOnScanComplete = value } }
            )
        )
    }

    private func settingsRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typefaces.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                Text(subtitle)
                    .font(Typefaces.mono(11))
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            MavlosToggle(isOn: isOn)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }

    // MARK: - Colonna destra

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("regole")
            rulesCard

            ActionButton(
                kind: .secondary,
                title: L.s("Aggiungi regola"),
                action: { ruleEditorContext = RuleEditorContext(existing: nil) }
            )
            .padding(.bottom, 14)

            SectionLabel("cronologia")
            historyCard
        }
        .frame(maxWidth: 380, alignment: .topLeading)
    }

    /// Regole mostrate: predefinite (con eventuali destinazioni sovrascritte,
    /// mai eliminabili) + regole personalizzate ordinate per priorità.
    private func allDisplayRules() -> [OrganizationRule] {
        var overrides: [FileCategory: URL] = [:]
        for (raw, path) in state.settings.preferences.destinationOverrides {
            if let category = FileCategory(rawValue: raw) {
                overrides[category] = URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        let system = OrganizationRule.systemRules(destinationOverrides: overrides)
        let custom = state.settings.preferences.customRules.sorted { $0.priority > $1.priority }
        return system + custom
    }

    private var rulesCard: some View {
        let rules = allDisplayRules()

        return VStack(spacing: 0) {
            ForEach(rules) { rule in
                RuleRow(
                    rule: rule,
                    onEdit: rule.isSystem ? nil : { ruleEditorContext = RuleEditorContext(existing: rule) },
                    onDelete: rule.isSystem ? nil : { ruleToDelete = rule },
                    onChangeDestination: { changeRuleDestination(rule) }
                )
                if rule.id != rules.last?.id {
                    rowSeparator
                }
            }
        }
        .card(radius: 14)
    }

    private func changeRuleDestination(_ rule: OrganizationRule) {
        Task {
            let urls = await state.chooseFolder(message: L.s("Nuova destinazione della regola"))
            guard let url = urls.first else { return }

            state.settings.update {
                if rule.isSystem {
                    $0.destinationOverrides[rule.category.rawValue] = url.standardizedFileURL.path
                } else {
                    var custom = $0.customRules
                    if let index = custom.firstIndex(where: { $0.id == rule.id }) {
                        custom[index].destination = url
                    }
                    $0.customRules = custom
                }
            }
        }
    }

    // MARK: - Cronologia (annullamento)

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let entry = lastJournalEntry {
                Text(entry.fileName)
                    .font(Typefaces.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(1)
                MonoValue(
                    "\(PathDefaults.compactPath(URL(fileURLWithPath: entry.originalPath))) → \(PathDefaults.compactPath(URL(fileURLWithPath: entry.finalPath)))",
                    size: 10.5
                )
                HStack {
                    MonoValue(formattedDate(entry.timestamp), size: 10)
                    Spacer()
                    ActionButton(
                        kind: .secondary,
                        title: L.s("Annulla ultima operazione"),
                        action: { state.undoLastOperation() }
                    )
                }
            } else {
                Text(L.s("Nessuna operazione recente."))
                    .font(Typefaces.small)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: 380, alignment: .leading)
        .card(radius: 14, fill: Palette.cardFill.opacity(0.85))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func refreshJournalEntry() {
        lastJournalEntry = state.journal.allRecords().last
    }
}

struct RuleEditorContext: Identifiable {
    let id = UUID()
    let existing: OrganizationRule?
}

/// Riga di una regola: pallino colorato, nome, freccia e destinazione.
private struct RuleRow: View {
    let rule: OrganizationRule
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onChangeDestination: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryDot(color: Palette.color(for: rule.category), size: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(rule.name)
                        .font(Typefaces.rowTitle)
                        .foregroundStyle(Palette.primaryText)
                    if !rule.isSystem {
                        Text("p\(rule.priority)")
                            .font(Typefaces.chip)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    if !rule.isActive {
                        Text(L.s("disattiva"))
                            .font(Typefaces.chip)
                            .foregroundStyle(Palette.mutedText)
                    }
                }
            }

            Spacer()

            MonoValue("→ \(PathDefaults.displayPath(rule.destination))", size: 11.5)

            menu
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    private var menu: some View {
        Menu {
            Button(L.s("Cambia destinazione…")) {
                onChangeDestination()
            }
            if let onEdit {
                Divider()
                Button(L.s("Modifica")) { onEdit() }
            }
            if let onDelete {
                Button(L.s("Elimina"), role: .destructive) { onDelete() }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .padding(6)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Editor di regole

private struct RuleEditorSheet: View {
    let existing: OrganizationRule?

    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var extensionsText = ""
    @State private var destination: URL?
    @State private var category: FileCategory = .documents
    @State private var priority = 5
    @State private var isActive = true
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? L.s("Aggiungi regola") : L.s("Modifica regola"))
                .font(Typefaces.sectionTitle)
                .foregroundStyle(Palette.primaryText)

            field(L.s("Nome")) {
                TextField(L.s("Regola personalizzata"), text: $name)
            }

            field(L.s("Estensioni")) {
                TextField(L.s("es. pdf, docx, md"), text: $extensionsText)
            }

            field(L.s("Categoria")) {
                Picker("Categoria", selection: $category) {
                    ForEach(FileCategory.allCases, id: \.self) { candidate in
                        Text(candidate.displayName).tag(candidate)
                    }
                }
                .pickerStyle(.menu)
            }

            field(L.s("Cartella di destinazione")) {
                HStack {
                    MonoValue(
                        destination.map { PathDefaults.displayPath($0) } ?? "—",
                        size: 11.5
                    )
                    Spacer()
                    ActionButton(
                        kind: .secondary,
                        title: L.s("Scegli"),
                        icon: "folder",
                        action: {
                            Task {
                                let urls = await state.chooseFolder(
                                    message: L.s("Cartella di destinazione della regola")
                                )
                                if let url = urls.first {
                                    destination = url
                                }
                            }
                        }
                    )
                }
            }

            field(L.s("Priorità")) {
                HStack(spacing: 10) {
                    Stepper(value: $priority, in: 1...9) {
                        Text("\(priority)")
                            .font(Typefaces.mono(13, .semibold))
                            .foregroundStyle(Palette.primaryText)
                    }
                    Text(L.s("una priorità più alta viene applicata prima"))
                        .font(Typefaces.micro)
                        .foregroundStyle(Palette.mutedText)
                }
            }

            HStack {
                Text(L.s("Regola attiva"))
                    .font(Typefaces.rowTitle)
                    .foregroundStyle(Palette.primaryText)
                Spacer()
                MavlosToggle(isOn: $isActive)
            }

            if let message = validationMessage {
                Text(message)
                    .font(Typefaces.mono(11))
                    .foregroundStyle(Palette.warningAmber)
            }

            HStack {
                Spacer()
                ActionButton(kind: .secondary, title: L.s("Annulla")) {
                    dismiss()
                }
                ActionButton(kind: .primary, title: L.s("Salva"), icon: "checkmark") {
                    save()
                }
            }
        }
        .padding(26)
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x2A2A2F))
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { hydrate() }
    }

    private func field<V: View>(_ label: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typefaces.mono(10))
                .kerning(0.6)
                .foregroundStyle(Palette.primaryText.opacity(0.45))
            content()
        }
    }

    private func hydrate() {
        guard let existing = existing else { return }
        name = existing.name
        extensionsText = Array(existing.extensions).sorted().joined(separator: ", ")
        destination = existing.destination
        category = existing.category
        priority = existing.priority
        isActive = existing.isActive
    }

    private func save() {
        let extensions = extensionsText
            .split(whereSeparator: { $0 == "," })
            .map { FileCategory.normalized(String($0)) }
            .filter { !$0.isEmpty }

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = L.s("Assegna un nome alla regola.")
            return
        }
        guard !extensions.isEmpty else {
            validationMessage = L.s("Inserisci almeno un'estensione.")
            return
        }
        guard let destination = destination else {
            validationMessage = L.s("Scegli la cartella di destinazione.")
            return
        }

        let rule = OrganizationRule(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            extensions: OrganizationRule.normalize(extensions),
            destination: destination,
            category: category,
            priority: priority,
            isActive: isActive,
            isSystem: false
        )

        state.settings.update {
            if let existing = existing,
               let index = $0.customRules.firstIndex(where: { $0.id == existing.id }) {
                $0.customRules[index] = rule
            } else {
                $0.customRules.append(rule)
            }
        }

        dismiss()
    }
}
