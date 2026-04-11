#!/usr/bin/env sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "macOS release signing is only supported on macOS." >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage:
  ./scripts/release/release-macos.sh github
  ./scripts/release/release-macos.sh appstore

Environment:
  WISERONE_APP_NAME                      Default: WiserOne
  WISERONE_PRODUCT_NAME                  Default: WiserOne
  WISERONE_BUNDLE_ID                     Default: com.sebastienrousseau.wiserone
  WISERONE_VERSION                       Default: 0.0.0
  WISERONE_MIN_MACOS                     Default: 13.0
  WISERONE_DIST_DIR                      Default: dist

GitHub channel (Developer ID):
  WISERONE_DEVELOPER_ID_APP              Required. Example: Developer ID Application: Name (TEAMID)
  WISERONE_NOTARY_PROFILE                Optional. notarytool keychain profile name.

App Store channel:
  WISERONE_APPSTORE_APP_IDENTITY         Required. Example: Apple Distribution: Name (TEAMID)
  WISERONE_APPSTORE_INSTALLER_IDENTITY   Required. Example: 3rd Party Mac Developer Installer: Name (TEAMID)
  WISERONE_APPSTORE_PROFILE              Required. Path to provisioning profile.
  WISERONE_APPSTORE_ENTITLEMENTS         Optional. Default: config/entitlements/appstore.plist
  WISERONE_ASC_API_KEY                   Optional. App Store Connect API key id for upload.
  WISERONE_ASC_ISSUER_ID                 Optional. App Store Connect issuer id for upload.
USAGE
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_env() {
    var_name="$1"
    value="${2:-}"
    if [ -z "$value" ]; then
        echo "Missing required environment variable: $var_name" >&2
        exit 1
    fi
}

require_signing_identity() {
    identity="$1"
    if ! security find-identity -v -p codesigning 2>/dev/null | grep -F "$identity" >/dev/null 2>&1; then
        echo "Signing identity not found in keychain: $identity" >&2
        echo "Available identities:" >&2
        security find-identity -v -p codesigning || true
        exit 1
    fi
}

build_release_binary() {
    swift build -c release --product "$WISERONE_PRODUCT_NAME"
    BIN_DIR="$(swift build -c release --show-bin-path)"
    BIN_PATH="$BIN_DIR/$WISERONE_PRODUCT_NAME"
    if [ ! -x "$BIN_PATH" ]; then
        echo "Release binary not found: $BIN_PATH" >&2
        exit 1
    fi
}

write_info_plist() {
    plist_path="$APP_PATH/Contents/Info.plist"
    cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${WISERONE_APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${WISERONE_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${WISERONE_APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${WISERONE_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${WISERONE_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${WISERONE_MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
}

build_app_bundle() {
    APP_PATH="$WISERONE_DIST_DIR/${WISERONE_APP_NAME}.app"
    rm -rf "$APP_PATH"
    mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

    cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$WISERONE_APP_NAME"
    chmod 755 "$APP_PATH/Contents/MacOS/$WISERONE_APP_NAME"

    bundle_count=0
    for bundle in "$BIN_DIR"/*.bundle; do
        if [ -d "$bundle" ]; then
            cp -R "$bundle" "$APP_PATH/Contents/Resources/"
            bundle_count=$((bundle_count + 1))
        fi
    done
    if [ "$bundle_count" -eq 0 ]; then
        echo "No SwiftPM resource bundles found in $BIN_DIR." >&2
        exit 1
    fi

    write_info_plist
}

sign_github_app() {
    require_env WISERONE_DEVELOPER_ID_APP "${WISERONE_DEVELOPER_ID_APP:-}"
    require_signing_identity "$WISERONE_DEVELOPER_ID_APP"

    codesign --force --timestamp --options runtime --sign "$WISERONE_DEVELOPER_ID_APP" "$APP_PATH/Contents/MacOS/$WISERONE_APP_NAME"
    codesign --force --timestamp --options runtime --sign "$WISERONE_DEVELOPER_ID_APP" "$APP_PATH"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    spctl --assess --type execute --verbose=4 "$APP_PATH"
}

notarize_and_staple_if_configured() {
    if [ -z "${WISERONE_NOTARY_PROFILE:-}" ]; then
        return
    fi

    require_command xcrun
    temp_zip="$WISERONE_DIST_DIR/${WISERONE_APP_NAME}-notary-submit.zip"
    rm -f "$temp_zip"
    ditto -c -k --keepParent "$APP_PATH" "$temp_zip"
    xcrun notarytool submit "$temp_zip" --keychain-profile "$WISERONE_NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_PATH"
    rm -f "$temp_zip"
}

package_github_zip() {
    ZIP_PATH="$WISERONE_DIST_DIR/${WISERONE_APP_NAME}-macos-${WISERONE_VERSION}.zip"
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "GitHub release artifact ready: $ZIP_PATH"
}

sign_appstore_app() {
    require_env WISERONE_APPSTORE_APP_IDENTITY "${WISERONE_APPSTORE_APP_IDENTITY:-}"
    require_env WISERONE_APPSTORE_INSTALLER_IDENTITY "${WISERONE_APPSTORE_INSTALLER_IDENTITY:-}"
    require_env WISERONE_APPSTORE_PROFILE "${WISERONE_APPSTORE_PROFILE:-}"
    require_signing_identity "$WISERONE_APPSTORE_APP_IDENTITY"
    require_signing_identity "$WISERONE_APPSTORE_INSTALLER_IDENTITY"

    if [ ! -f "$WISERONE_APPSTORE_PROFILE" ]; then
        echo "Provisioning profile not found: $WISERONE_APPSTORE_PROFILE" >&2
        exit 1
    fi
    if [ ! -f "$WISERONE_APPSTORE_ENTITLEMENTS" ]; then
        echo "Entitlements file not found: $WISERONE_APPSTORE_ENTITLEMENTS" >&2
        exit 1
    fi

    cp "$WISERONE_APPSTORE_PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"

    codesign --force --timestamp --sign "$WISERONE_APPSTORE_APP_IDENTITY" --entitlements "$WISERONE_APPSTORE_ENTITLEMENTS" "$APP_PATH/Contents/MacOS/$WISERONE_APP_NAME"
    codesign --force --timestamp --sign "$WISERONE_APPSTORE_APP_IDENTITY" --entitlements "$WISERONE_APPSTORE_ENTITLEMENTS" "$APP_PATH"
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
}

package_appstore_pkg() {
    PKG_PATH="$WISERONE_DIST_DIR/${WISERONE_APP_NAME}-appstore-${WISERONE_VERSION}.pkg"
    rm -f "$PKG_PATH"
    productbuild --component "$APP_PATH" /Applications --sign "$WISERONE_APPSTORE_INSTALLER_IDENTITY" "$PKG_PATH"
    pkgutil --check-signature "$PKG_PATH"
    echo "App Store package ready: $PKG_PATH"
}

upload_appstore_if_configured() {
    if [ -z "${WISERONE_ASC_API_KEY:-}" ] || [ -z "${WISERONE_ASC_ISSUER_ID:-}" ]; then
        echo "Skipping App Store upload. Set WISERONE_ASC_API_KEY and WISERONE_ASC_ISSUER_ID to upload."
        return
    fi

    xcrun iTMSTransporter \
        -m upload \
        -assetFile "$PKG_PATH" \
        -apiKey "$WISERONE_ASC_API_KEY" \
        -apiIssuer "$WISERONE_ASC_ISSUER_ID"
}

require_command swift
require_command codesign
require_command security
require_command ditto
require_command productbuild
require_command pkgutil
require_command spctl

CHANNEL="${1:-}"
if [ -z "$CHANNEL" ]; then
    usage
    exit 1
fi

WISERONE_APP_NAME="${WISERONE_APP_NAME:-WiserOne}"
WISERONE_PRODUCT_NAME="${WISERONE_PRODUCT_NAME:-WiserOne}"
WISERONE_BUNDLE_ID="${WISERONE_BUNDLE_ID:-com.sebastienrousseau.wiserone}"
WISERONE_VERSION="${WISERONE_VERSION:-0.0.0}"
WISERONE_MIN_MACOS="${WISERONE_MIN_MACOS:-13.0}"
WISERONE_DIST_DIR="${WISERONE_DIST_DIR:-dist}"
WISERONE_APPSTORE_ENTITLEMENTS="${WISERONE_APPSTORE_ENTITLEMENTS:-config/entitlements/appstore.plist}"

mkdir -p "$WISERONE_DIST_DIR"

build_release_binary
build_app_bundle

case "$CHANNEL" in
    github)
        sign_github_app
        notarize_and_staple_if_configured
        package_github_zip
        ;;
    appstore)
        sign_appstore_app
        package_appstore_pkg
        upload_appstore_if_configured
        ;;
    *)
        usage
        exit 1
        ;;
esac
