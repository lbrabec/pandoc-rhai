#!/bin/bash
# Download cabal-install source and bootstrap dependencies for offline build.
# Fetch phase — requires network access.
#
# Usage: ./scripts/fetch_cabal_deps.sh [OUTPUT_DIR]
set -euo pipefail

GHC_VERSION="9.6.4"
CABAL_VERSION="3.12.1.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
OUTPUT_DIR="${1:-${PROJECT_DIR}/cabal-bootstrap}"

mkdir -p "${OUTPUT_DIR}/bootstrap-deps"

# Download cabal source
CABAL_SRC="${OUTPUT_DIR}/cabal-${CABAL_VERSION}-src.tar.gz"
if [[ -f "${CABAL_SRC}" ]]; then
    echo ">>> Cabal ${CABAL_VERSION} source already exists, skipping..."
else
    echo ">>> Downloading cabal ${CABAL_VERSION} source from GitHub..."
    curl -L --progress-bar \
        "https://github.com/haskell/cabal/archive/refs/tags/cabal-install-v${CABAL_VERSION}.tar.gz" \
        -o "${CABAL_SRC}"
fi

# Extract bootstrap plan and download deps
echo ">>> Downloading cabal-install bootstrap dependencies..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

tar xf "${CABAL_SRC}" -C "${TEMP_DIR}"
CABAL_SRC_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d -name "cabal-*" | head -1)
BOOTSTRAP_JSON="${CABAL_SRC_DIR}/bootstrap/linux-${GHC_VERSION}.json"

if [[ ! -f "${BOOTSTRAP_JSON}" ]]; then
    echo "ERROR: Bootstrap config not found: ${BOOTSTRAP_JSON}" >&2
    echo "Available plans:" >&2
    ls -la "${CABAL_SRC_DIR}/bootstrap/"*.json 2>/dev/null || echo "  (none)" >&2
    exit 1
fi

python3 "${SCRIPT_DIR}/download_bootstrap_deps.py" "${BOOTSTRAP_JSON}" "${OUTPUT_DIR}/bootstrap-deps"

echo ""
echo "=== Cabal bootstrap sources ready ==="
echo "Source: ${CABAL_SRC}"
echo "Bootstrap deps: $(find "${OUTPUT_DIR}/bootstrap-deps" -name '*.tar.gz' | wc -l) packages"
