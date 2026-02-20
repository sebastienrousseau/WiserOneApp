#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLATPAK_DIR="${ROOT_DIR}/packaging/flatpak"
BUILD_DIR="${FLATPAK_DIR}/build"
REPO_DIR="${FLATPAK_DIR}/repo"
SRC_DIR="${FLATPAK_DIR}/src"
MANIFEST="${FLATPAK_DIR}/com.wiserone.WiserOne.json"
BUNDLE_OUT="${FLATPAK_DIR}/WiserOne.flatpak"

mkdir -p "${BUILD_DIR}" "${REPO_DIR}" "${SRC_DIR}"

# Stage sources without local .git and large unrelated folders
rsync -a --delete \
  --exclude .git \
  --exclude .flatpak-builder \
  --exclude Linux_Dynamic_Wallpapers \
  --exclude build \
  --exclude build-* \
  --exclude packaging/flatpak/src \
  --exclude packaging/flatpak/build \
  --exclude packaging/flatpak/repo \
  --exclude packaging/appimage/AppDir \
  --exclude packaging/appimage/tools \
  "${ROOT_DIR}/" "${SRC_DIR}/"

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak-builder --force-clean --install-deps-from=flathub --disable-updates --repo="${REPO_DIR}" "${BUILD_DIR}" "${MANIFEST}"
flatpak build-bundle "${REPO_DIR}" "${BUNDLE_OUT}" com.wiserone.WiserOne
