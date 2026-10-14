#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace}"
BUILD_KIND="${1:-debug-apk}"
GODOT_BIN="${GODOT_BIN:-godot}"
OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_DIR}/build}"

cd "${PROJECT_DIR}"

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
"${GODOT_BIN}" --headless --path "${PROJECT_DIR}" --script res://tests/player_controller_test.gd

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
