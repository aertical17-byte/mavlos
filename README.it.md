# mavlos

**mavlos** è un'app nativa per macOS che riordina le tue cartelle in sicurezza:
scansiona i file reali sul disco, li classifica per categoria, ti mostra un
**anteprima completa** di ogni spostamento e li organizza solo dopo la tua
conferma esplicita. Nessun file viene mai cancellato, sovrascritto o spostato
senza che tu lo veda prima.

- **Interfaccia in italiano** (traduzione inglese inclusa)
- **Motore di scansione reale** con contatori vivi di avanzamento
- **Anteprima e revisione**: per lotti o file per file
- **Annulla tutto** tramite registro delle operazioni (journal)
- **Scansioni programmabili** (giornaliera / settimanale / mensile): calcolano
  solo le proposte, non spostano mai nulla in autonomia

---

## Requisiti

| Componente | Valore |
| --- | --- |
| Sistema | macOS 13.0 o successivo (architettura arm64) |
| Strumenti | Swift / Command Line Tools 5.9+ (sviluppato e verificato con Swift 6.0.3) |

Non è richiesto Xcode completo: basta Xcode Command Line Tools.

## Compilazione ed esecuzione

```bash
# debug + tutti i test
swift build
swift test

# pacchetto .app firmato ad hoc in artifacts/
Scripts/make_app.sh
open artifacts/Mavlos.app
```

Se era già in esecuzione una copia precedente, chiudila prima di sostituire il
bundle: `pkill -x Mavlos`.

## Architettura

Due target Swift Package Manager (`Package.swift`, tools-version 5.9):

```
MavlosCore        Libreria UI-free: scansioni, classificazione, spostamenti,
                  regole, impostazioni, notifiche. Testabile in riga di comando.

Mavlos            Applicazione eseguibile (SwiftUI).

├ Sources/Mavlos/App        MavlosApp, AppDelegate, AppState (stato centrale)
├ Sources/Mavlos/Views      Home, selezione cartelle, avanzamento, risultati,
│                           revisione, impostazioni, sidebar
├ Sources/Mavlos/DesignSystem  Colori, tipografia (mono per percorsi/bottoni),
│                              card, sfondo, componenti
├ Sources/Mavlos/L10n.swift    Localizzazione (L.s / L.formatted)
└ Sources/MavlosCore/…        Vedi tabella sotto
```

Moduli chiave di `MavlosCore`:

| File | Ruolo |
| --- | --- |
| `FileScanner.swift` | Scansione ricorsiva o media del disco con snapshot di avanzamento; esclude libreria di sistema, bundle/pacchetti, link simbolici e file nascosti |
| `FileClassifier.swift` | Assegna ogni file a una categoria in base a estensione, regole utente ed euristica |
| `FileOrganizer.swift` / `OrganizationService.swift` | Costruiscono ed eseguono le proposte di spostamento, gestendo conflitti e rinomine alternative |
| `FileMover.swift` / `OperationRecord.swift` | Spostamenti atomici + journal per l'annullamento (ripristino anche con renome) |
| `DuplicateDetector.swift` | Individua file omonimi e conflitti di destinazione |
| `PermissionManager.swift` / `BookmarkService.swift` | Accesso alle cartelle solo via `NSOpenPanel` + security-scoped bookmarks |
| `SettingsService.swift` | Impostazioni persistenti (JSON) e pianificazione scansioni |

Le immagini del robot (mascotte) e l'icona dell'app sono generate dallo script
CoreGraphics `Scripts/mascotgen.swift` (eseguirlo dalla radice del progetto:
`swift Scripts/mascotgen.swift`) e vivono in `Assets/`.

## Sicurezza

- **Nessuna cancellazione, mai.** Le operazioni sono solo riorganizzazioni di
  spostamento visibili in anteprima.
- **Nulla si muove senza conferma**: ogni passaggio richiede l'approvazione
  esplicita; è possibile revisionare uno per uno.
- **Conflitti**: quando la destinazione è occupata, l'app propone di mantenere
  entrambi i file rinominando `nome (2).est`, oppure di saltare il file.
- **Cartelle escluse**: libreria di sistema, pacchetti/bundle, link simbolici e
  file nascosti non vengono mai toccati.
- **Permessi**: l'accesso richiede solo la finestra standard di apertura
  cartelle, mai *Full Disk Access*. Le scelte persistono tramite bookmark
  security-scoped.
- **Scansioni programmate**: calcolano i risultati e, al massimo, mostrano una
  notifica: nessuno spostamento automatico.

## Limitazioni note

- Le scansioni programmate funzionano **solo con l'app in esecuzione** (non è
  un agente di sistema separato).
- Al primo accesso a una cartella protetta, macOS può mostrare il prompt TCC
  standard: l'app non aggira i controlli di sistema.
- In ambiente di sviluppo remoto/senza interfaccia grafica gli screenshot del
  terminale richiedono il permesso di Registrazione schermo macOS; l'app in sé
  avvia normalmente una finestra 1180×732.

## Test

I test usano **Swift Testing** (`import Testing`, `@Test`, `#expect`) e
operano **esclusivamente su directory temporanee**: nessun test tocca le
cartelle reali dell'utente.

```bash
swift test    # 74 test: classificatore, scanner, duplicati, mover, organizer,
              # impostazioni, formattazione e percorsi
```

## Pacchetto

`Scripts/make_app.sh` esegue la build release, assembla `artifacts/Mavlos.app`
(con Info.plist, icona, localizzazioni it/en) e lo firma ad hoc. Verifica:

```bash
codesign -v artifacts/Mavlos.app     # signature OK
plutil -lint artifacts/Mavlos.app/Contents/Info.plist
```

Footer dell'app: `mavlos 1.0 · macOS`.
