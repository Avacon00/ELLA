#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADDON_NAME="ELLA"

TARGET_ADDONS_DIR="${1:-}"

if [[ -z "${TARGET_ADDONS_DIR}" ]]; then
    echo "Usage: $0 \"/path/to/World of Warcraft/_forever_/Interface/AddOns\""
    echo ""
    echo "Tip (Linux / Faugus / Wine / Lutris / Steam / Bottles):"
    echo "  Pass the path to your '_forever_/Interface/AddOns' directory to create"
    echo "  a live development symlink so '/reload' in WoW picks up changes immediately."
    exit 1
fi

mkdir -p "${TARGET_ADDONS_DIR}"
DEST="${TARGET_ADDONS_DIR}/${ADDON_NAME}"

if [[ -L "${DEST}" ]]; then
    rm "${DEST}"
elif [[ -e "${DEST}" ]]; then
    echo "Error: '${DEST}' already exists and is not a symlink. Move or back it up first."
    exit 1
fi

ln -s "${ADDON_ROOT}" "${DEST}"
echo "Linked ${ADDON_NAME} -> ${DEST}"
echo "Launch WoW: Forever (or type /reload in-game) to test!"
