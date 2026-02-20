#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build-appimage"
APPDIR="${ROOT_DIR}/packaging/appimage/AppDir"
APPIMAGE_TOOL_DIR="${ROOT_DIR}/packaging/appimage/tools"

mkdir -p "${BUILD_DIR}" "${APPDIR}" "${APPIMAGE_TOOL_DIR}"

LINUXDEPLOY="${APPIMAGE_TOOL_DIR}/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT="${APPIMAGE_TOOL_DIR}/linuxdeploy-plugin-qt-x86_64.AppImage"

if [[ ! -f "${LINUXDEPLOY}" ]]; then
  curl -L -o "${LINUXDEPLOY}" "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
  chmod +x "${LINUXDEPLOY}"
fi

if [[ ! -f "${LINUXDEPLOY_QT}" ]]; then
  curl -L -o "${LINUXDEPLOY_QT}" "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"
  chmod +x "${LINUXDEPLOY_QT}"
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" -j
cmake --install "${BUILD_DIR}" --prefix "${APPDIR}/usr"

export QML_SOURCES_PATHS="${ROOT_DIR}/resources/qml"

# AppImage expects appdata.xml; duplicate metainfo for compatibility.
if [[ -f "${APPDIR}/usr/share/metainfo/com.wiserone.WiserOne.metainfo.xml" ]]; then
  cp "${APPDIR}/usr/share/metainfo/com.wiserone.WiserOne.metainfo.xml" \
     "${APPDIR}/usr/share/metainfo/com.wiserone.WiserOne.appdata.xml"
fi

"${LINUXDEPLOY}" \
  --appdir "${APPDIR}" \
  --desktop-file "${ROOT_DIR}/resources/linux/com.wiserone.WiserOne.desktop" \
  --icon-file "${ROOT_DIR}/resources/icons/icon-512.png" \
  --plugin qt \
  --output appimage
