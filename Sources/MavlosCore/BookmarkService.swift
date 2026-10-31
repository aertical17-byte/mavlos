import Foundation

/// Persistenza dei Security-Scoped Bookmarks per le cartelle scelte
/// dall'utente con il selettore nativo. Anche se Mavlos non è sandboxed di
/// default, l'architettura è predisposta: attivando la sandbox l'app
/// recupererebbe gli accessi senza dispersione.
public enum BookmarkService {

    private static let storageKey = "mavlos.folderBookmarks"

    private static var storage: [String: Data] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Data] ?? [:]
    }

    /// Conserva il bookmark di una cartella ricevuta dal selettore nativo.
    public static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return
        }
        var current = storage
        current[url.standardizedFileURL.path] = data
        UserDefaults.standard.set(current, forKey: storageKey)
    }

    /// Ripristina i percorsi registrati, scartando quelli non più risolvibili.
    public static func resolvedFolders() -> [URL] {
        let saved = storage
        var resolved: [URL] = []
        var stillValid: [String: Data] = [:]

        for (path, data) in saved {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                resolved.append(url)
                let anchor = stale ? url.standardizedFileURL.path : path
                stillValid[anchor] = data
            }
        }

        if stillValid.count != saved.count {
            UserDefaults.standard.set(stillValid, forKey: storageKey)
        }
        return resolved
    }

    /// Rimuove un percorso dal registro dei bookmark.
    public static func removeBookmark(for url: URL) {
        var current = storage
        current.removeValue(forKey: url.standardizedFileURL.path)
        UserDefaults.standard.set(current, forKey: storageKey)
    }
}
