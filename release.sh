#!/bin/zsh
# Archives QRule and exports an App Store Connect-ready QRule.pkg.
#
# Usage:
#   ./release.sh [version] [build]      # exports dist/QRule.pkg — upload via Transporter/Organizer
#   ./release.sh --upload [version] [build]   # uploads straight to App Store Connect
#
# Defaults: version 1.0, build = timestamp (App Store requires a unique,
# increasing build number for every upload).
#
# Prerequisites:
#   - Bundle ID com.danielbond.QRule registered at developer.apple.com
#   - App record created in App Store Connect
#   - Xcode signed in to the Apple ID (Settings > Accounts) so
#     -allowProvisioningUpdates can create/download profiles
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEAM_ID="WJ8R7FHAJ8"
ARCHIVE="$PROJECT_DIR/build/QRule.xcarchive"
DIST_DIR="$PROJECT_DIR/dist"

UPLOAD=false
if [[ "${1:-}" == "--upload" ]]; then
    UPLOAD=true
    shift
fi
VERSION="${1:-1.0}"
BUILD="${2:-$(date +%Y%m%d%H%M)}"

cd "$PROJECT_DIR"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Archiving QRule $VERSION ($BUILD)"
rm -rf "$ARCHIVE"
xcodebuild archive \
    -project QRule.xcodeproj \
    -scheme QRule \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD"

# Swap the KeyboardShortcuts package's ru localization for our uk one
# (same step as build.sh, applied to the archived app). Re-sign with the
# development identity so the archive stays valid; the export step below
# re-signs everything with the distribution certificate anyway.
APP="$ARCHIVE/Products/Applications/QRule.app"
KS_RES="$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle/Contents/Resources"
if [[ -d "$KS_RES" ]]; then
    echo "==> Localizations: removing ru.lproj, adding uk.lproj"
    rm -rf "$KS_RES/ru.lproj"
    mkdir -p "$KS_RES/uk.lproj"
    cp "$PROJECT_DIR/Localization/KeyboardShortcuts-uk.strings" "$KS_RES/uk.lproj/Localizable.strings"
    # The nested bundle must carry the distribution cert: exportArchive
    # re-signs the app itself but leaves nested resource bundles untouched
    # (ITMS-90284 otherwise).
    codesign --force --sign "Apple Distribution" \
        "$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
    codesign --force --sign "Apple Development" \
        --entitlements "$PROJECT_DIR/QRule/Support/QRule.entitlements" \
        "$APP"
fi

DESTINATION=$([[ "$UPLOAD" == true ]] && echo upload || echo export)
EXPORT_OPTIONS="$PROJECT_DIR/build/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>destination</key>
	<string>$DESTINATION</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

echo "==> Exporting ($DESTINATION)"
mkdir -p "$DIST_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$DIST_DIR" \
    -allowProvisioningUpdates

if [[ "$UPLOAD" == true ]]; then
    echo "Uploaded QRule $VERSION ($BUILD) to App Store Connect."
    echo "It will appear under TestFlight/Builds after processing (~15 min)."
else
    echo "Done: $DIST_DIR/QRule.pkg"
    echo "Upload it with the Transporter app, or rerun with --upload."
fi
