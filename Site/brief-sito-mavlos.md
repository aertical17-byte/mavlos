# Brief — Sito vetrina per **mavlos** 1.0

> Da consegnare così com'è al creatore del sito. Tutto ciò che è scritto qui
> deriva dall'app reale: usare testi e colori indicati senza modificarli.

---

## 1 · Il progetto

Serve una **one-page vetrina professionale in italiano** (eventuale paginetta
FAQ/Changelog separata) per **mavlos**, applicazione nativa macOS che riordina
le cartelle dell'utente in totale sicurezza, **con download diretto dal sito**
(file .zip/.dmg, senza registrazione, senza account).

**mavlos in una frase:** scansiona le cartelle reali del Mac, classifica i file
per categoria, mostra un'anteprima completa di ogni spostamento e li organizza
solo dopo la conferma esplicita dell'utente. **Non cancella mai, non
sovrascrive mai, non sposta mai nulla senza approvazione.**

Il sito deve trasmettere, in quest'ordine: (1) fiducia e sicurezza,
(2) semplicità d'uso, (3) la personalità visiva dell'app (robot bianco, tema
scuro).

---

## 2 · Identità visiva (da rispettare alla lettera)

Palette ufficiale dell'app, da replicare nel sito (valori esatti):

| Uso | Hex |
| --- | --- |
| Sfondo ambientale scuro | `#101114` |
| Sidebar / superfici di navigazione | `#26384F` |
| Card / pannelli | `#343438` |
| Blu — categoria "Immagini" / accento primario | `#69A8FF` |
| Giallo — categoria "Documenti · Lavoro" | `#E9B64F` |
| Verde — categoria "Archivi" / conferme OK | `#69C591` |
| Viola — categoria "Musica" | `#A58BEA` |
| Testo primario | near-white `#F2F3F5` |
| Testo secondario | grigio `#9BA0AA` |

- **Tema scuro unico** (nessuna light-mode alternativa: la vetrina deve sembrare l'app).
- Tipografia: font geometrico moderno per titoli e corpo; **font monospace per
  tutti gli elementi "tecnici"**: percorsi di file (es. `~/Scaricati/foto.jpg`),
  bottoni d'installazione, numeri di versione, blocchi di nota. L'uso del mono
  è parte dell'identità: accento di personalità, non corpo di testo.
- Raggio angoli 12–18px su card e bottoni (mai punte diritte, mai fake-circolari).
- Contrasto WCAG AA sul tema scuro (testo secondario su `#101114` ≥ 4.5:1).
- Mascotte: **robot bianco illustrato** con visore lucido e archi luminosi blu
  di sorriso, che tiene una cartellina azzurra. Riceverete PNG trasparenti ad
  alta risoluzione: usarlo così com'è, NON ridisegnarlo in altro stile.
- Footer del sito identico a quello dell'app: `mavlos 1.0 · macOS`.

---

## 3 · Cosa fa l'app (contenuti reali da usare)

Le **6 categorie** dell'app (colori in §2): Immagini · Documenti
(etichetta breve "Lavoro") · Musica · Video · Archivi · Altri file.

**Flusso in 4 passi** (da narrare con illustrazioni/mockup):

1. **Scegli le cartelle** — tramite la finestra standard di macOS, niente
   permessi estorti, niente "Accesso completo al disco".
2. **Scansione reale** — contatori vivi durante il processo; esclude
   automaticamente libreria di sistema, bundle/app, file nascosti e link
   simbolici.
3. **Anteprima completa** — per lotti o file per file: per ogni file si vede
   dove andrà, prima che si muova un singolo byte.
4. **Organizza o Annulla** — con conferma si esegue il piano; se la
   destinazione è occupata, si decide per ogni caso: rinomina in
   `nome (2).est` oppure salta.

**Griglia funzionalità:**

- Classificazione automatica per estensione + regole personalizzabili
- Riepilogo con **barre proporzionali** colorate per categoria
- Revisione **per lotti e uno a uno**: Sposta / Salta / Mantieni entrambi
- **Annulla tutto** — journal delle operazioni con ripristino (funziona anche
  se la posizione originale è stata già occupata: ripristina rinominando)
- **Scansioni programmate** (giornaliera / settimanale / mensile): calcolano le
  proposte e notificano; **mai** spostamenti automatici
- Impostazioni persistenti, destinazioni personalizzate per categoria
- Interfaccia in italiano (traduzione inglese inclusa)

**Fatti di fiducia/privacy** — la sezione centrale del sito, è il vero
argomento di vendita:

- 100% **offline**: nessun dato lascia il Mac, nessuna telemetria, nessun account
- Mai "Accesso completo al disco": solo il meccanismo standard macOS
  (NSOpenPanel + bookmark security-scoped)
- Non cancella e non sovrascrive mai nulla
- Se macOS chiede un'autorizzazione al primo accesso a una cartella protetta,
  è il sistema che parla: l'app non aggira i controlli di sistema
- Sviluppo metodico: suite di **74 test automatici** che operano solo su
  directory temporanee, mai sui file reali dell'utente

---

## 4 · Requisiti sistema / blocco download

- Nome prodotto: **mavlos** (una parola, tutto minuscolo)
- Versione corrente: **1.0**
- Piattaforma: **macOS 13 (Ventura) o successivo · Apple Silicon**
- Download: file ZIP/DMG pronto, link diretto, nessuna registrazione
- **Nota Gatekeeper**, da inserire come box/accordion nel blocco download:
  l'app è firmata con certificato "ad hoc" (sviluppatore indipendente), quindi
  al primo avvio macOS può dire "mavlos non può essere verificato". Didascalia
  in 2 righe: tasto destro sull'icona → Apri → conferma; oppure Impostazioni →
  Privacy e sicurezza → "Apri comunque". Presentarlo come normalità
  trasparente, non come difetto da nascondere.
- Badge ammessi: "macOS 13+", "Apple Silicon", "gratis", "offline", "in italiano".
  Badge vietati: "certificato da Apple", "notarizzato", valutazioni store,
  recensioni finte.

---

## 5 · Struttura one-page (ordine e contenuti)

1. **Hero** — mascotte grande a destra, testo a sinistra. Titolo proposto:
   "Il tuo Mac, finalmente in ordine. Senza sorprese." Sottotitolo: "mavlos
   scansiona le tue cartelle, mostra l'anteprima di ogni spostamento e
   organizza solo quando dici tu." CTA primaria **[Scarica mavlos 1.0]** con
   micro-nota "macOS 13+ · Apple Silicon · download diretto"; CTA secondaria
   anchor "Vedi come funziona ↓".
2. **Come funziona** — i 4 passi del flusso (§3) con i mockup (§7).
3. **Sicurezza & privacy** — tre card affiancate: "Mai cancellato ·
   Mai sovrascritto · Mai senza controllo", seguito dai bullet (§3). Sezione
   chiave: darle spazio generoso.
4. **Funzionalità** — griglia delle feature (§3) con icone line e chip
   colorate per le 6 categorie.
5. **Perché mavlos** (opzionale, breve) — confronto onesto e sobrio:
   gli "optimizer" misurano; mavlos riordina. Zero fuffa.
6. **FAQ** — 5–6 domande reali: mavlos cancella file? · perché macOS lo
   segnala "non verificato"? · serve Full Disk Access? · l'app manda
   qualcosa online? · funziona su Mac Intel? · le scansioni programmate
   spostano da sole?
7. **Download** — blocco grande: file, versione, dimensione, SHA-256
   (fornito prima del deploy), nota Gatekeeper.
8. **Footer** — `mavlos 1.0 · macOS` + link minimi (Contatti, Changelog, Note legali).

Extra: dopo 480px di scroll, piccola **pillola CTA** fissa in basso con il
bottone "Scarica".

---

## 6 · Tech e hosting

- Sito **statico**, senza CMS: Astro / Vite+vanilla / Next static export;
  JavaScript minimo, nessun framework sovradimensionato.
- Hosting: Netlify o Vercel con deploy da repo + preview. Dominio: lo
  conferma il cliente prima del deploy.
- Performance: Lighthouse ≥ 95 su Performance, Accessibility, Best Practices,
  SEO; LCP < 2.0s; immagini WebP/AVIF con `srcset`.
- **Niente cookie banner**: nessun cookie di tracciamento. Se il cliente
  vuole analytics, solo privacy-first senza cookie (Plausible/Fathom).
- SEO on-page (lingua it): title "mavlos — riordina le cartelle del tuo Mac,
  in totale sicurezza"; meta-description ~155 caratteri con "organizzare file
  Mac"; Open Graph + Twitter card con OG-image prodotta dallo studio
  (mascotte + palette); favicon complete; `robots.txt` + `sitemap.xml`.
- Accessibilità: focus visibili, `prefers-reduced-motion`, animazioni
  sottili (fade/slide), niente parallax barocchi.
- Lingue: IT di default, EN su `/en/` tradotta con la stessa cura (no
  macchine-traduzioni crude).

---

## 7 · Asset forniti e mockup da produrre

**Riceverete dal cliente (usare tali e quali):**
- Mascotte: `mavlos-mascot.png` + `mavlos-mascot@2x.png` (PNG trasparenti)
- Icona app: `.icns` + set PNG 16→1024px
- Palette e regole di tipografia (§2). Coppia di font a scelta dello studio
  coerente col tema (es. Inter/Geist + JetBrains Mono).

**Da realizzare voi, fedeli all'aspetto dell'app (non esistono screenshot
reali usabili: i mockup sostituiscono ogni foto stock):**
- **Home** dell'app: sfondo `#101114`, sidebar `#26384F` con voci Home /
  Scansione / Impostazioni, mascotte al centro, bottoni fondenti in mono
  ("Scegli cartelle…", "Scansione programmata").
- **Risultati**: card `#343438` con barre orizzontali proporzionali nei
  quattro colori categoria.
- **Revisione**: liste di card file con percorso di origine e destinazione in
  font mono, badge di stato ("Nuovo", "Conflitto → nome (2).est", "Saltato").
- Icone micro in stile line (stroke ~1.5px) per la griglia funzionalità.

---

## 8 · Tono di voce

- **Italiano semplice e rassicurante**, frasi brevi, seconda persona
  ("le tue cartelle").
- Vietato marketing boom: niente "AI-powered", "rivoluzionario", "genius",
  "pulizia profonda". mavlos non è uno "cleaner": è un assistente che
  riordina e protegge i file.
- Ogni promessa deve essere verificabile con un comportamento reale
  dell'app: mai promettere funzioni inesistenti.
- Umorismo leggero ammesso se sobrio; mai fear-marketing ("il tuo Mac è pieno
  di spazzatura!" — vietato).

---

## 9 · Da confermare col cliente prima del deploy (non inventare risposte)

1. **Licenza/prezzo**: gratuita da download diretto, gratuita con donazione
   ("supporta il progetto") o a pagamento con licenza? Il blocco download
   cambia per ognuna delle tre strade.
2. Dominio definitivo e hosting effettivo.
3. URL stabile del file di distribuzione + hash SHA-256 da esporre.
4. Pagina "Changelog" già predisposta per la versione futura 1.1.
5. Eventuale futura firma Apple Developer ID: il box Gatekeeper va progettato
   per lasciare il posto a un futuro "verificato da Apple".

---

## 10 · Deliverables

- Sorgenti in repo git + deploy production attivo.
- OG-image 1200×630, favicons complete, sitemap, robots.
- Contatto semplice (mailto o form minimo, senza gestione dati personali).
- Un meccanismo per aggiornare versione e file di download senza toccare il
  codice (es. `site.config.json` o frontmatter).
- Verifica finale documentata: download reale testato, Lighthouse ≥ 95,
  tutti gli anchor funzionanti.
