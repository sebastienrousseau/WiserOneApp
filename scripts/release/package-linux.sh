#!/usr/bin/env sh
set -eu

if [ "$(uname -s)" != "Linux" ]; then
    echo "This script packages Linux artifacts and must run on Linux." >&2
    exit 1
fi

PRODUCT_NAME="${WISERONE_PRODUCT_NAME:-WiserOne}"
PACKAGE_NAME="${WISERONE_PACKAGE_NAME:-wiserone}"
VERSION="${1:-${WISERONE_VERSION:-0.0.0}}"
DIST_DIR="${WISERONE_DIST_DIR:-dist}"
MAINTAINER="${WISERONE_MAINTAINER:-Sebastien Rousseau <sebastien@wiserone.com>}"
URL="${WISERONE_URL:-https://github.com/sebastienrousseau/WiserOneApp}"
DESCRIPTION="${WISERONE_DESCRIPTION:-Daily quotes app package payload for Linux distributions.}"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

map_rpm_arch() {
    case "$1" in
        amd64) echo "x86_64" ;;
        arm64) echo "aarch64" ;;
        *) echo "$1" ;;
    esac
}

map_arch_pkg_arch() {
    case "$1" in
        amd64) echo "x86_64" ;;
        arm64) echo "aarch64" ;;
        *) echo "$1" ;;
    esac
}

write_launcher() {
    launcher_path="$1"
    cat >"$launcher_path" <<LAUNCHER
#!/usr/bin/env sh
exec /opt/${PACKAGE_NAME}/${PRODUCT_NAME} "\$@"
LAUNCHER
    chmod 755 "$launcher_path"
}

build_deb() {
    root="$1"
    output_path="$2"
    architecture="$3"

    installed_size="$(du -sk "$root" | awk '{print $1}')"

    mkdir -p "$root/DEBIAN"
    cat >"$root/DEBIAN/control" <<CONTROL
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${architecture}
Maintainer: ${MAINTAINER}
Installed-Size: ${installed_size}
Homepage: ${URL}
Description: ${DESCRIPTION}
CONTROL

    dpkg-deb --build "$root" "$output_path" >/dev/null
}

build_rpm() {
    stage_root="$1"
    output_dir="$2"
    deb_arch="$3"

    rpm_arch="$(map_rpm_arch "$deb_arch")"
    rpmbuild_root="$tmp_dir/rpmbuild"
    source_root="$tmp_dir/rpm-source/${PACKAGE_NAME}-${VERSION}"
    spec_path="$rpmbuild_root/SPECS/${PACKAGE_NAME}.spec"

    mkdir -p \
        "$rpmbuild_root/BUILD" \
        "$rpmbuild_root/RPMS" \
        "$rpmbuild_root/SOURCES" \
        "$rpmbuild_root/SPECS" \
        "$rpmbuild_root/SRPMS" \
        "$source_root"

    cp -R "$stage_root"/* "$source_root/"
    tar -C "$tmp_dir/rpm-source" -czf "$rpmbuild_root/SOURCES/${PACKAGE_NAME}-${VERSION}.tar.gz" "${PACKAGE_NAME}-${VERSION}"

    cat >"$spec_path" <<SPEC
Name:           ${PACKAGE_NAME}
Version:        ${VERSION}
Release:        1
Summary:        ${DESCRIPTION}
License:        MIT OR Apache-2.0
URL:            ${URL}
Source0:        %{name}-%{version}.tar.gz
BuildArch:      ${rpm_arch}

%description
${DESCRIPTION}

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}
cp -a opt %{buildroot}/
cp -a usr %{buildroot}/

%files
/opt/${PACKAGE_NAME}
/usr/bin/${PACKAGE_NAME}
/usr/share/doc/${PACKAGE_NAME}

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') ${MAINTAINER} - ${VERSION}-1
- Automated package build
SPEC

    rpmbuild --define "_topdir ${rpmbuild_root}" -bb "$spec_path" >/dev/null

    built_rpm="$(find "$rpmbuild_root/RPMS" -type f -name '*.rpm' | head -n 1)"
    if [ -z "$built_rpm" ]; then
        echo "RPM build failed: no artifact generated." >&2
        exit 1
    fi

    cp "$built_rpm" "$output_dir/"
}

build_arch_pkg() {
    stage_root="$1"
    output_path="$2"
    deb_arch="$3"

    arch_arch="$(map_arch_pkg_arch "$deb_arch")"
    arch_root="$tmp_dir/arch-root"
    size_bytes="$(du -sb "$stage_root" | awk '{print $1}')"
    build_date="$(date +%s)"

    rm -rf "$arch_root"
    mkdir -p "$arch_root"
    cp -R "$stage_root"/* "$arch_root/"

    cat >"$arch_root/.PKGINFO" <<PKGINFO
pkgname = ${PACKAGE_NAME}
pkgbase = ${PACKAGE_NAME}
pkgver = ${VERSION}-1
pkgdesc = ${DESCRIPTION}
url = ${URL}
builddate = ${build_date}
packager = ${MAINTAINER}
size = ${size_bytes}
arch = ${arch_arch}
license = MIT
license = Apache-2.0
PKGINFO

    tar -C "$arch_root" -cf - . | zstd -q -19 -T0 -o "$output_path"
}

require_command swift
require_command dpkg-deb
require_command rpmbuild
require_command tar
require_command zstd

mkdir -p "$DIST_DIR"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/wiserone-release-linux.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

swift build -c release --product "$PRODUCT_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"

if [ ! -x "$BIN_PATH" ]; then
    echo "Release binary not found: $BIN_PATH" >&2
    exit 1
fi

deb_arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
rpm_arch="$(map_rpm_arch "$deb_arch")"
arch_pkg_arch="$(map_arch_pkg_arch "$deb_arch")"

stage_root="$tmp_dir/stage"
mkdir -p \
    "$stage_root/opt/${PACKAGE_NAME}" \
    "$stage_root/usr/bin" \
    "$stage_root/usr/share/doc/${PACKAGE_NAME}"

cp "$BIN_PATH" "$stage_root/opt/${PACKAGE_NAME}/${PRODUCT_NAME}"
chmod 755 "$stage_root/opt/${PACKAGE_NAME}/${PRODUCT_NAME}"

for candidate in "$BIN_DIR"/*.bundle "$BIN_DIR"/*.resources; do
    if [ -d "$candidate" ]; then
        cp -R "$candidate" "$stage_root/opt/${PACKAGE_NAME}/"
    fi
done

write_launcher "$stage_root/usr/bin/${PACKAGE_NAME}"
cp README.md "$stage_root/usr/share/doc/${PACKAGE_NAME}/README.md"

DEB_PATH="$DIST_DIR/${PACKAGE_NAME}_${VERSION}_${deb_arch}.deb"
RPM_PATH="$DIST_DIR/${PACKAGE_NAME}-${VERSION}-1.${rpm_arch}.rpm"
ARCH_PATH="$DIST_DIR/${PACKAGE_NAME}-${VERSION}-1-${arch_pkg_arch}.pkg.tar.zst"

rm -f "$DEB_PATH" "$RPM_PATH" "$ARCH_PATH"

build_deb "$stage_root" "$DEB_PATH" "$deb_arch"
build_rpm "$stage_root" "$DIST_DIR" "$deb_arch"

built_rpm="$(find "$DIST_DIR" -maxdepth 1 -type f -name "${PACKAGE_NAME}-${VERSION}-1*.rpm" | head -n 1)"
if [ -z "$built_rpm" ]; then
    echo "RPM artifact missing after build." >&2
    exit 1
fi
if [ "$built_rpm" != "$RPM_PATH" ]; then
    mv "$built_rpm" "$RPM_PATH"
fi

build_arch_pkg "$stage_root" "$ARCH_PATH" "$deb_arch"

echo "Created artifacts:"
echo "- $DEB_PATH"
echo "- $RPM_PATH"
echo "- $ARCH_PATH"
