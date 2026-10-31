<div align="center">

<img src="Assets/mavlos-mascot.png" alt="mavlos — the white robot mascot holding a blue folder" width="220">

# mavlos

🤖 Organize the folders on your Mac — with a silent robot, file previews, and an undo-everything feature.

**Native macOS app · Italian-first UI (English included) · 100% offline**

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-26384F?logo=apple)](#requirements)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-26384F)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-69A8FF?logo=swift)](#build-from-source)
[![Tests](https://img.shields.io/badge/tests-74%20passing-69C591)](#testing)
[![Privacy: offline](https://img.shields.io/badge/privacy-local_only-A58BEA)](#safety--privacy)

</div>

---

mavlos scans your real folders, classifies every file, shows you a **complete preview of each move** — and only acts after your explicit confirmation.

It never deletes. It never overwrites. It never moves anything you haven't approved.

> The boring part is automatic (scan, classify, propose).
> The dangerous part is yours (the final click).

## ✨ Features

| | |
| --- | --- |
| 🗂 **Smart classification** | Six categories — Images, Documents, Music, Video, Archives, Others — by extension, plus **user-defined rules** that take priority |
| 👓 **Full preview** | Proportional summary bars per category, then per-file review: source → destination, before a single byte moves |
| 🔄 **Batch or one-by-one** | Approve a whole plan in one click, or walk through files with *Move / Skip / Keep both* |
| ⏪ **Undo everything** | An operation journal restores every file — even if the original spot got occupied in the meantime (it renames around it) |
| 🕑 **Scheduled scans** | Daily / weekly / monthly. They only *prepare proposals* and notify you — **never move anything on their own** |
| 🧩 **Conflict-safe** | Destination occupied? Choose per-file: rename to `name (2).ext` or skip |
| 🎯 **Custom destinations** | Decide where each category should land, with settings that persist |
| 🌍 **Italian-first** | The UI speaks Italian by design; the English localization ships in the bundle |

## 🔐 Safety & privacy

This is the product's core, not the fine print:

- **100% local.** No data ever leaves your Mac. No accounts, no telemetry, no "cloud hygiene score".
- **Never asks for Full Disk Access.** Folder access goes through the standard macOS open panel and persists via security-scoped bookmarks only.
- **Nothing is ever deleted or overwritten.** It's a filing assistant, not a "cleaner".
- **System folders are untouchable.** Library, app bundles, hidden files and symlinks are excluded from scanning by design.
- **macOS TCC prompts are your friend.** If the system asks permission for a protected folder, that's the OS doing its job — mavlos doesn't work around it.
- **Tested like it matters.** 74 automated tests (Swift Testing) run exclusively on temporary directories — never on your real files.

## 💡 How it works

1. **Pick folders** — through the standard macOS open panel
2. **Real scan** — with live counters; hidden files, bundles and system paths are skipped automatically
3. **Full preview** — per category summary, then file-by-file review of every move
4. **Organize or Undo** — execute the plan on your confirmation, or roll it back from the journal

## 📥 Download

Grab the latest bundle from **[Releases](../../releases)** (`.app`, packed via the build script).

**Requirements:** macOS 13 (Ventura) or later · Apple Silicon.

> **First launch note:** mavlos is signed *ad hoc* by an independent developer, so macOS may say it "cannot be verified". That's normal Gatekeeper behavior for unsigned dev tools. Right-click the app → **Open** → confirm (or System Settings → Privacy & Security → *Open Anyway*). Nothing modifying anything — the prompt is macOS being the bouncer, and mavlos respects it.

## 🚀 Quick start

1. Launch **mavlos**
2. Click *Scegli cartelle…* and select the folder(s) to tidy (e.g. `Downloads`)
3. Review the summary and proposals — bar chart first, file list second
4. Organize. Regret something? Undo from the journal. Done.

## 🔧 Build from source

No full Xcode needed — Command Line Tools suffice.

```bash
# debug build + full test suite
swift build
swift test

# signed, packaged .app → artifacts/Mavlos.app
Scripts/make_app.sh

# regenerate the mascot and the app icon
swift Scripts/mascotgen.swift   # run from the project root
```

Open `artifacts/Mavlos.app` and you're done — the application lives in the app bundle with its mascot, icon, and both localizations.

## 🧪 Testing

The suite uses [Swift Testing](https://github.com/swiftlang/swift-testing) and covers the classifier, scanner (recursion, hidden files, symlinks, cancelled scans, progress snapshots), duplicate detection, the move engine (conflicts, keep-both renames, undo, journal persistence), the organizer pipeline, and settings persistence.

```bash
swift test   # 74 tests, ~2s
```

Every test works on temporary directories only. Nothing touches your real filesystem.

## 🏗 Architecture

Two SPM targets, clean separation between logic and UI:

| Target | What it holds |
| --- | --- |
| **MavlosCore** | UI-free library — classifier, scanner, mover, organizer, journal, settings, permissions, notifications. Fully testable from the CLI |
| **Mavlos** | SwiftUI executable — views (home, folder selection, scan progress, results, review, settings), dark design system, localization |

The heart of the design: **never trust silence**. Every destructive-looking action shows its preview first, every move is journaled, and the journal survives app restarts (`.iso8601`, capped at 500 entries). The scheduled engine *prepares* work but the human decides when it lands.

## 🗺 Roadmap

- [ ] Code-signed + notarized release (Gatekeeper box goes away)
- [ ] English-first UI toggle at first launch
- [ ] Rule editor polish (import/export rule books)
- [ ] Scheduled scan notifications with direct "review now" deep link

## 📄 License

To be added before publishing. *(Suggested for a "free + donation" model: MIT or GPL-3.0 — pick and replace this line.)*

---

<div align="center">

*Filed with care by a white robot with a shiny visor and a glowing blue smile.* 🤖

**mavlos 1.0 · macOS**

Italian documentation: [README.it.md](README.it.md)

</div>
