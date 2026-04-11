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
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
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

resolve_logo_svg() {
    for candidate in \
        "$REPO_ROOT/sources/resources/logo.svg" \
        "$REPO_ROOT/sources/assets.xcassets/logo.imageset/logo.svg" \
        "$REPO_ROOT/sources/assets.xcassets/logo.svg"
    do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
    return 1
}

render_logo_png() {
    logo_svg="$1"
    output_png="$2"

    swift - "$logo_svg" "$output_png" <<'SWIFT'
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Invalid icon render arguments.\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: args[1])
let destinationURL = URL(fileURLWithPath: args[2])
let size = CGSize(width: 1024, height: 1024)

guard let image = NSImage(contentsOf: sourceURL) else {
    fputs("Failed to load SVG logo.\n", stderr)
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to allocate bitmap for icon rendering.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
if let context = NSGraphicsContext(bitmapImageRep: rep) {
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
}
NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to export PNG icon.\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: destinationURL)
} catch {
    fputs("Failed to write PNG icon: \(error)\n", stderr)
    exit(1)
}
SWIFT
}

build_icns_from_logo() {
    output_icns="$1"
    tmp_icon_dir="$(mktemp -d "${TMPDIR:-/tmp}/wiserone-icon.XXXXXX")"
    iconset_dir="$tmp_icon_dir/AppIcon.iconset"
    master_png="$tmp_icon_dir/logo-1024.png"

    trap 'rm -rf "$tmp_icon_dir"' EXIT INT TERM

    mkdir -p "$iconset_dir"

    logo_svg="$(resolve_logo_svg || true)"
    if [ -n "$logo_svg" ]; then
        if ! render_logo_png "$logo_svg" "$master_png"; then
            echo "Warning: SVG icon render failed, falling back to app iconset PNG." >&2
        fi
    fi

    if [ ! -f "$master_png" ]; then
        fallback_png="$REPO_ROOT/sources/assets.xcassets/AppIcon.appiconset/512x512@2x.png"
        if [ ! -f "$fallback_png" ]; then
            echo "No icon source available for app bundle." >&2
            exit 1
        fi
        cp "$fallback_png" "$master_png"
    fi

    for spec in \
        "16 icon_16x16.png" \
        "32 icon_16x16@2x.png" \
        "32 icon_32x32.png" \
        "64 icon_32x32@2x.png" \
        "128 icon_128x128.png" \
        "256 icon_128x128@2x.png" \
        "256 icon_256x256.png" \
        "512 icon_256x256@2x.png" \
        "512 icon_512x512.png" \
        "1024 icon_512x512@2x.png"
    do
        size="${spec%% *}"
        filename="${spec#* }"
        sips -s format png -z "$size" "$size" "$master_png" --out "$iconset_dir/$filename" >/dev/null
    done

    iconutil -c icns "$iconset_dir" -o "$output_icns"
    rm -rf "$tmp_icon_dir"
    trap - EXIT INT TERM
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
require_command sips
require_command iconutil

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
build_icns_from_logo "$APP_PATH/Contents/Resources/AppIcon.icns"
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
