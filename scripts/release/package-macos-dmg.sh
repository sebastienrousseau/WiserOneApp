#!/usr/bin/env sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script packages macOS artifacts and must run on macOS." >&2
    exit 1
fi

APP_NAME="${WISERONE_APP_NAME:-WiserOne}"
PRODUCT_NAME="${WISERONE_PRODUCT_NAME:-WiserOne}"
BUNDLE_ID="${WISERONE_BUNDLE_ID:-com.sebastienrousseau.wiserone}"
VERSION="${1:-${WISERONE_VERSION:-0.0.0}}"
MIN_MACOS="${WISERONE_MIN_MACOS:-13.0}"
DIST_DIR="${WISERONE_DIST_DIR:-dist}"
SIGNING_IDENTITY="${WISERONE_DEVELOPER_ID_APP:-}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

write_info_plist() {
    plist_path="$1"
    cat >"$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
}

copy_runtime_bundles() {
    source_bin_dir="$1"
    destination_dir="$2"

    for candidate in "$source_bin_dir"/*.bundle "$source_bin_dir"/*.resources; do
        if [ -d "$candidate" ]; then
            cp -R "$candidate" "$destination_dir/"
        fi
    done
}

sign_app_bundle() {
    app_path="$1"

    if [ -n "$SIGNING_IDENTITY" ]; then
        require_command security
        require_command spctl
        if ! security find-identity -v -p codesigning 2>/dev/null | grep -F "$SIGNING_IDENTITY" >/dev/null 2>&1; then
            echo "Signing identity not found: $SIGNING_IDENTITY" >&2
            exit 1
        fi
        codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$app_path/Contents/MacOS/$APP_NAME"
        codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$app_path"
        codesign --verify --deep --strict --verbose=2 "$app_path"
        spctl --assess --type execute --verbose=4 "$app_path"
        return
    fi

    codesign --force --sign - "$app_path/Contents/MacOS/$APP_NAME"
    codesign --force --sign - "$app_path"
}

require_command swift
require_command hdiutil
require_command ditto
require_command codesign

mkdir -p "$DIST_DIR"

swift build -c release --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"

if [ ! -x "$BIN_PATH" ]; then
    echo "Release binary not found: $BIN_PATH" >&2
    exit 1
fi

APP_PATH="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}-macos-${VERSION}.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}-macos-${VERSION}.zip"

rm -rf "$APP_PATH"
rm -f "$DMG_PATH" "$ZIP_PATH"

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_PATH/Contents/MacOS/$APP_NAME"
copy_runtime_bundles "$BIN_DIR" "$APP_PATH/Contents/Resources"
write_info_plist "$APP_PATH/Contents/Info.plist"
sign_app_bundle "$APP_PATH"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Created artifacts:"
echo "- $DMG_PATH"
echo "- $ZIP_PATH"
