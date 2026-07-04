#!/bin/zsh
# Builds the Release version of QRule and packages QRule.app into dist/.
# Usage: ./build.sh [--install]   (--install also copies the app to /Applications)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"

cd "$PROJECT_DIR"

# Always regenerate so newly added source files are picked up
echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
xcodebuild \
    -project QRule.xcodeproj \
    -scheme QRule \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

APP="$BUILD_DIR/Build/Products/Release/QRule.app"

echo "==> Packaging into dist/"
rm -rf "$DIST_DIR/QRule.app"
mkdir -p "$DIST_DIR"
ditto "$APP" "$DIST_DIR/QRule.app"

# The KeyboardShortcuts package ships its own localizations (incl. Russian,
# but no Ukrainian). Swap ru → uk using our translation, then re-sign since
# changing bundle resources invalidates the signature.
KS_RES="$DIST_DIR/QRule.app/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle/Contents/Resources"
if [[ -d "$KS_RES" ]]; then
    echo "==> Localizations: removing ru.lproj, adding uk.lproj"
    rm -rf "$KS_RES/ru.lproj"
    mkdir -p "$KS_RES/uk.lproj"
    cp "$PROJECT_DIR/Localization/KeyboardShortcuts-uk.strings" "$KS_RES/uk.lproj/Localizable.strings"
    SIGN_IDENTITY="Apple Development"
    codesign --force --sign "$SIGN_IDENTITY" "$DIST_DIR/QRule.app/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
    codesign --force --sign "$SIGN_IDENTITY" \
        --entitlements "$PROJECT_DIR/QRule/Support/QRule.entitlements" \
        "$DIST_DIR/QRule.app"
fi

echo "==> Verifying signature"
codesign --verify --deep "$DIST_DIR/QRule.app"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> Installing to /Applications"
    if pgrep -xq QRule; then
        osascript -e 'quit app "QRule"' || true
        sleep 1
    fi
    rm -rf /Applications/QRule.app
    ditto "$DIST_DIR/QRule.app" /Applications/QRule.app
    open /Applications/QRule.app
    echo "==> Installed and launched /Applications/QRule.app"
fi

echo "Done: $DIST_DIR/QRule.app"
