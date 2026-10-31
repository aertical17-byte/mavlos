import Foundation

/// Risoluzione e rappresentazione dei percorsi utente.
public enum PathDefaults {
    private static var cachedHome: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    public static func homeDirectory() -> URL { cachedHome }

    /// Scaricamenti ~/Downloads
    public static func downloadsURL() -> URL? {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    /// Scrivania ~/Desktop
    public static func desktopURL() -> URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    /// Documenti ~/Documents
    public static func documentsURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    public static func destination(for category: FileCategory) -> URL? {
        category.defaultDestinationURL()
    }

    // MARK: - Rappresentazione

    /// Percorso abbreviato con la tilde: /Users/m.x/Downloads -> ~/Downloads
    public static func compactPath(_ url: URL) -> String {
        let home = cachedHome.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path != home else { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    /// Percorso localizzato per l'utente: usa le denominazioni di sistema
    /// (su macOS italiano: ~/Immagini, ~/Musica, ~/Film, ~/Documenti/Lavoro).
    public static func displayPath(_ url: URL) -> String {
        let fm = FileManager.default
        let home = cachedHome

        guard url.path.hasPrefix(home.path) && url.path != home.path else {
            return compactPath(url)
        }

        let relative = url.path.dropFirst(home.path.count)   // "/Downloads/a"
        var components = relative.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return "~" }

        // Localizza i componenti che corrispondono a cartelle di sistema reali.
        let standardDirectories: [FileManager.SearchPathDirectory] = [
            .downloadsDirectory, .desktopDirectory, .documentDirectory,
            .picturesDirectory, .musicDirectory, .moviesDirectory
        ]
        var searchURL = home
        for index in components.indices where index < 3 {
            let candidate = searchURL.appendingPathComponent(components[index], isDirectory: true)
            let isSystemFolder = standardDirectories.contains { dir in
                fm.urls(for: dir, in: .userDomainMask).first?.standardizedFileURL.path
                    == candidate.standardizedFileURL.path
            }
            if isSystemFolder {
                components[index] = fm.displayName(atPath: candidate.path)
            }
            searchURL = candidate
        }

        return "~/" + components.joined(separator: "/")
    }

    /// True se `child` è lungo la gerarchia di `parent` (percorsi standardizzati).
    public static func isInside(_ child: URL, of parent: URL) -> Bool {
        let parentPath = parent.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path
        if childPath == parentPath { return false }
        return childPath.hasPrefix(parentPath + "/")
    }
}
