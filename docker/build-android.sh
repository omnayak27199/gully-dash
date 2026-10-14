#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace}"
BUILD_KIND="${1:-debug-apk}"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"

cd "${PROJECT_DIR}"

# The image keeps read-only templates and SDK settings under /opt/godot.
# Copy them into the caller's writable HOME so Godot finds them under non-root.
USER_HOME="${HOME:-/root}"
TEMPLATE_SOURCE="/opt/godot/export_templates/${GODOT_VERSION:-4.7.2}.stable"
TEMPLATE_DEST="${USER_HOME}/.local/share/godot/export_templates/${GODOT_VERSION:-4.7.2}.stable"
mkdir -p "${USER_HOME}/.local/share/godot/export_templates" "${USER_HOME}/.config/godot"
if [[ ! -f "${TEMPLATE_SOURCE}/android_debug.apk" || ! -f "${TEMPLATE_SOURCE}/android_release.apk" ]]; then
  echo "ERROR: matching Android export templates are missing from ${TEMPLATE_SOURCE}" >&2
  find /opt/godot/export_templates -maxdepth 3 -type f -print >&2 || true
  exit 4
fi
mkdir -p "${TEMPLATE_DEST}"
cp -a "${TEMPLATE_SOURCE}/." "${TEMPLATE_DEST}/"
if [[ ! -s "${TEMPLATE_DEST}/android_debug.apk" || ! -s "${TEMPLATE_DEST}/android_release.apk" ]]; then
  echo "ERROR: Android export templates were not copied into ${TEMPLATE_DEST}" >&2
  find "${TEMPLATE_DEST}" -maxdepth 2 -type f -print >&2 || true
  exit 5
fi
if [[ -f /opt/godot/editor_settings-4.tres && ! -f "${USER_HOME}/.config/godot/editor_settings-4.tres" ]]; then
  cp /opt/godot/editor_settings-4.tres "${USER_HOME}/.config/godot/editor_settings-4.tres"
fi

if [[ ! -f project.godot ]]; then
  echo "ERROR: project.godot was not found in ${PROJECT_DIR}" >&2
  exit 2
fi

mkdir -p "${OUTPUT_DIR}"

echo "==> Engine version"
"${GODOT_BIN}" --headless --version

echo "==> Importing project and validating resources"
"${GODOT_BIN}" --headless --editor --path "${PROJECT_DIR}" --quit

echo "==> Running player-controller tests"
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" res://tests/player_controller_test.tscn

echo "==> Running gameplay integration tests"
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" res://tests/game_smoke_test.tscn

echo "==> Running save manager persistence tests"
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" res://tests/save_manager_test.tscn

case "${BUILD_KIND}" in
  debug-apk)
    PRESET="Android Debug"
    OUTPUT_FILE="${OUTPUT_DIR}/GullyDash-debug.apk"
    echo "==> Exporting ${PRESET} to ${OUTPUT_FILE}"
    "${GODOT_BIN}" --headless --path "${PROJECT_DIR}" --export-debug "${PRESET}" "${OUTPUT_FILE}"
    ;;
  *)
    echo "ERROR: Unsupported build kind '${BUILD_KIND}'. Supported: debug-apk" >&2
    exit 2
    ;;
esac

if [[ ! -s "${OUTPUT_FILE}" ]]; then
  echo "ERROR: Export reported success but output is missing/empty: ${OUTPUT_FILE}" >&2
  exit 3
fi

file "${OUTPUT_FILE}" || true
sha256sum "${OUTPUT_FILE}"
echo "BUILD_SUCCESS: ${OUTPUT_FILE}"
