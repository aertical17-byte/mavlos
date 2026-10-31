import Foundation
import UniformTypeIdentifiers

/// Esito della classificazione di un file.
public struct Classification: Sendable, Hashable {
    public var category: FileCategory
    public var destination: URL?
    public var status: ClassificationStatus
    /// Suggerimento informativo (non determina lo spostamento).
    public var hint: String?
    /// Origine della classificazione: nome della regola, "estensione", "tipo di file" o "da verificare".
    public var ruleName: String?

    public init(category: FileCategory, destination: URL?, status: ClassificationStatus, hint: String? = nil, ruleName: String? = nil) {
        self.category = category
        self.destination = destination
        self.status = status
        self.hint = hint
        self.ruleName = ruleName
    }
}

/// Libro di regole: regole predefinite (derivate da `FileCategory`, con
/// eventuali destinazioni sovrascritte dall'utente) e regole personalizzate
/// ordinate per priorità. Classificazione locale, deterministica, veloce.
public struct RuleBook: Sendable {
    private let customRules: [OrganizationRule]
    private let systemOverrides: [FileCategory: URL]

    public init(customRules: [OrganizationRule] = [], systemOverrides: [FileCategory: URL] = [:]) {
        self.customRules = Self.sortedActive(customRules)
        self.systemOverrides = systemOverrides
    }

    private static func sortedActive(_ rules: [OrganizationRule]) -> [OrganizationRule] {
        guard !rules.isEmpty else { return [] }
        return rules
            .enumerated()
            .filter { $0.element.isActive }
            .sorted { lhs, rhs in
                lhs.element.priority != rhs.element.priority
                    ? lhs.element.priority > rhs.element.priority
                    : lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    /// Classifica un file per estensione, regole personalizzate e tipo UTI.
    public func classify(name: String, fileExtension: String) -> Classification {
        let ext = FileCategory.normalized(fileExtension)

        // 1. Regole personalizzate attive, in ordine di priorità.
        for rule in customRules where rule.matches(fileExtension: ext) {
            return Classification(
                category: rule.category,
                destination: rule.destination,
                status: .classified,
                ruleName: rule.name
            )
        }

        // 2. Estensione nota ai cataloghi di Mavlos.
        if let category = FileCategory(fileExtension: ext) {
            let destination = systemOverrides[category] ?? category.defaultDestinationURL()
            if let destination {
                return .init(category: category, destination: destination, status: .classified, ruleName: "estensione")
            }
            return .init(category: category, destination: nil, status: .needsReview, hint: nil, ruleName: "estensione")
        }

        // 3. Tipo di file (UTI) per estensioni non catalogate.
        if let advice = Self.classifyByType(extension: ext) {
            return advice
        }

        // 4. Non classificato: nessuna categoria inventata, resta "Altri file".
        return .init(
            category: .others,
            destination: nil,
            status: .needsReview,
            hint: Self.nameHint(for: name),
            ruleName: "da verificare"
        )
    }

    // MARK: - Fallback per tipo

    private static func classifyByType(extension ext: String) -> Classification? {
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return nil }

        func advice(_ category: FileCategory) -> Classification {
            .init(
                category: category,
                destination: category.defaultDestinationURL(),
                status: .classified,
                hint: "Riconosciuto dal tipo di file",
                ruleName: "tipo di file"
            )
        }

        if type.conforms(to: .image) { return advice(.images) }
        if type.conforms(to: .movie) { return advice(.video) }
        if type.conforms(to: .audio) { return advice(.music) }
        if type.conforms(to: .archive) { return advice(.archives) }
        if type.conforms(to: .pdf) || type.conforms(to: .plainText) || type.conforms(to: .rtf)
            || type.conforms(to: .spreadsheet) || type.conforms(to: .presentation) || type.conforms(to: .text)
        {
            return advice(.documents)
        }
        return nil
    }

    // MARK: - Suggerimenti dal nome

    private static let documentKeywords: Set<String> = [
        "fattura", "invoice", "bolletta", "contratto", "preventivo", "budget",
        "cv", "curriculum", "report", "relazione", "denuncia", "ricevuta",
        "certificato", "contratto", " documento", "appunto", "nota", "ricevuto"
    ]
    private static let screenshotKeywords: Set<String> = [
        "schermata", "screenshot", "screen shot", "cattura"
    ]

    /// Suggerimento informativo per file sconosciuti: non modifica la classificazione.
    static func nameHint(for name: String) -> String? {
        let lower = name.lowercased()
        if screenshotKeywords.contains(where: lower.contains) {
            return "Sembra una schermata: puoi assegnarla a Immagini."
        }
        if documentKeywords.contains(where: lower.contains) {
            return "Sembra un documento di lavoro."
        }
        return nil
    }
}
