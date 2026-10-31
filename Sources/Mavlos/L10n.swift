import Foundation

/// Aiuto alla localizzazione: le stringhe italiane sono il testo di default
/// del codice; la tabella `Localizable` (es. en.lproj/Localizable.strings)
/// consente di aggiungere altre lingue in futuro senza toccare le viste.
enum L {
    static func s(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }

    /// Format con argomenti (rispetta la locale italiana per i separatori).
    static func formatted(_ format: String, _ arguments: CVarArg...) -> String {
        String(
            format: s(format),
            locale: Locale(identifier: "it_IT"),
            arguments: arguments
        )
    }
}
