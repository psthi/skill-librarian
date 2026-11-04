#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_URL="https://raw.githubusercontent.com/psthi/skill-librarian/main"
INSTALL_DIR="${HOME}/.local/bin"
TARGET_BIN="${INSTALL_DIR}/skill-lib"

mkdir -p "${INSTALL_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [ -n "${SCRIPT_DIR}" ] && [ -f "${SCRIPT_DIR}/bin/skill-lib" ]; then
    cp "${SCRIPT_DIR}/bin/skill-lib" "${TARGET_BIN}"
else
    echo "Downloading skill-lib from ${REPO_RAW_URL}/bin/skill-lib ..."
    curl -fsSL "${REPO_RAW_URL}/bin/skill-lib" -o "${TARGET_BIN}"
fi

chmod +x "${TARGET_BIN}"
echo "Installed skill-lib to ${TARGET_BIN}"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
    echo "Note: Add ${INSTALL_DIR} to your PATH if not already present:"
    echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

"${TARGET_BIN}" init "$@"
"${TARGET_BIN}" list
