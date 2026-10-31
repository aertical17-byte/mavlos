#!/bin/zsh
# Assembles artifacts/Mavlos.app from a release build of the Swift package.
#
#   swift test      (opzionale, prima)
#   ./Scripts/make_app.sh
#
# Structure:
#   Mavlos.app/
#     Contents/MacOS/Mavlos              (binario release)
#     Contents/Resources/mavlos-icon.icns
#     Contents/Resources/mavlos-mascot*.png
#     Contents/Resources/en.lproj/Localizable.strings
#     Contents/Info.plist

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Mavlos"
APP_DIR="$ROOT/artifacts/$APP_NAME.app"
BUNDLE_ID="it.mavlos.$APP_NAME"

cd "$ROOT"

echo "→ swift build --release"
swift build -c release

BIN="$ROOT/.build/release/$APP_NAME"
[[ -x "$BIN" ]] || { echo "binario mancante: $BIN"; exit 1; }

echo "→ struttura .app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Assets/mavlos-icon.icns" "$APP_DIR/Contents/Resources/"
cp "$ROOT/Assets/mavlos-mascot.png" "$APP_DIR/Contents/Resources/"
cp "$ROOT/Assets/mavlos-mascot@2x.png" "$APP_DIR/Contents/Resources/"
mkdir -p "$APP_DIR/Contents/Resources/en.lproj"
cp "$ROOT/Assets/Localizable/en.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/en.lproj/"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>mavlos</string>
    <key>CFBundleDisplayName</key>
    <string>mavlos</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>it</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>it</string>
        <string>en</string>
    </array>
    <key>CFBundleIconFile</key>
    <string>mavlos-icon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 mavlos</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Mavlos legge il contenuto della Scrivania per proporti dove spostare i file.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Mavlos legge i nomi delle cartelle per spostare i documenti con la tua conferma.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Mavlos scansiona la cartella Download e suggerisce dove ordinare ogni file.</string>
</dict>
</plist>
PLIST

plutil -lint "$APP_DIR/Contents/Info.plist"

echo "→ firma ad hoc"
codesign --force --sign - --options runtime --timestamp=none "$APP_DIR" >/dev/null

echo "✓ creato: $APP_DIR"
