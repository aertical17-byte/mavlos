# Mavlos
🤖 Organize the folders on your Mac — with a silent robot, file previews, and an undo-everything feature.
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

**[Download the latest release →](../../releases/latest)** — the current asset is `mavlos-1.0.dmg` (built with `hdiutil`, volume "mavlos").

**Requirements:** macOS 13 (Ventura) or later · Apple Silicon.

| Asset | Size | macOS build |
| --- | --- | --- |
| `mavlos-1.0.dmg` | 3,8 MB | Release **v1.0** · SHA-256 `b7599f15bad661ce486c0588d8b5ed8dc435122fc86360b17bd4ef01578bffd1` |

> **First launch note:** mavlos is signed *ad hoc* by an independent developer, so macOS may say it "cannot be verified" on first launch. That's standard Gatekeeper behavior for unsigned dev tools — right-click the app → **Open** → confirm (or System Settings → Privacy & Security → *Open Anyway*). It's macOS playing bouncer, and mavlos respects it: no shady workarounds, no hidden installs.

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
