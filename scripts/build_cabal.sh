#!/bin/bash
# Build cabal-install from source using bootstrap.py.
# Build phase — no network access, fully offline.
#
# Requires env: GHC_PATH (directory containing ghc, ghc-pkg, etc.)
#
# Usage: ./scripts/build_cabal.sh [CABAL_BOOTSTRAP_DIR] [OUTPUT_DIR]
set -euo pipefail

GHC_BOOTSTRAP_PLAN="linux-9.6.4.json"
CABAL_VERSION="3.12.1.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

CABAL_BOOTSTRAP_DIR="${1:-${PROJECT_DIR}/cabal-bootstrap}"
OUTPUT_DIR="${2:-${PROJECT_DIR}/cabal-bin}"

: "${GHC_PATH:?GHC_PATH env var must be set (directory containing ghc)}"
export PATH="${GHC_PATH}:${PATH}"

CABAL_SRC="${CABAL_BOOTSTRAP_DIR}/cabal-${CABAL_VERSION}-src.tar.gz"
BOOTSTRAP_DEPS="${CABAL_BOOTSTRAP_DIR}/bootstrap-deps"

if [[ ! -f "${CABAL_SRC}" ]]; then
    echo "Error: cabal source not found: ${CABAL_SRC}" >&2
    echo "Run scripts/fetch_cabal_deps.sh first" >&2
    exit 1
fi

if [[ ! -d "${BOOTSTRAP_DEPS}" ]]; then
    echo "Error: bootstrap deps not found: ${BOOTSTRAP_DEPS}" >&2
    echo "Run scripts/fetch_cabal_deps.sh first" >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

echo "=== Building cabal-install ${CABAL_VERSION} ==="
echo "GHC:       $(ghc --version)"
echo "Bootstrap: ${CABAL_BOOTSTRAP_DIR}"
echo "Build:     ${BUILD_DIR}"

# Extract cabal source
tar xf "${CABAL_SRC}" -C "${BUILD_DIR}"
CABAL_SRC_DIR=$(find "${BUILD_DIR}" -maxdepth 1 -type d -name "cabal-*" | head -1)

cd "${CABAL_SRC_DIR}"

# Patch bootstrap plan to match the actual GHC's builtin package versions
GHC_PKG="$(command -v ghc-pkg)"
python3 "${SCRIPT_DIR}/fix_builtin_versions.py" \
    "bootstrap/${GHC_BOOTSTRAP_PLAN}" \
    "${GHC_PKG}"

# Build a sources tarball containing the plan + all deps, so bootstrap.py
# runs fully offline (the -s flag skips all network fetches)
SOURCES_TAR="${BUILD_DIR}/bootstrap-sources.tar.gz"
SOURCES_STAGING="${BUILD_DIR}/bootstrap-staging"
mkdir -p "${SOURCES_STAGING}"
cp "bootstrap/${GHC_BOOTSTRAP_PLAN}" "${SOURCES_STAGING}/plan-bootstrap.json"
cp "${BOOTSTRAP_DEPS}"/* "${SOURCES_STAGING}/"
tar czf "${SOURCES_TAR}" -C "${SOURCES_STAGING}" .

# Bootstrap cabal-install from the offline sources tarball
python3 bootstrap/bootstrap.py \
    -w "$(command -v ghc)" \
    -s "${SOURCES_TAR}"

# Install
mkdir -p "${OUTPUT_DIR}"
cp _build/bin/cabal "${OUTPUT_DIR}/cabal"
chmod +x "${OUTPUT_DIR}/cabal"

echo "=== cabal-install ${CABAL_VERSION} built ==="
"${OUTPUT_DIR}/cabal" --version
echo "Binary: ${OUTPUT_DIR}/cabal"
