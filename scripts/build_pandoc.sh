#!/bin/bash
# Build pandoc from pre-fetched hackage packages.
# Build phase — no network access, fully offline.
#
# Requires env: GHC_PATH      (directory containing ghc binary)
#               CABAL_PATH    (directory containing cabal binary, unless BUILD_CABAL=true)
#               BUILD_CABAL   (optional, "true" to bootstrap cabal-install from source)
#               CABAL_BOOTSTRAP_DIR (optional, path to cabal bootstrap sources)
#
# Usage: ./scripts/build_pandoc.sh [HACKAGE_DIR] [OUTPUT_DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

HACKAGE_DIR="${1:-${PROJECT_DIR}/hackage-packages}"
OUTPUT_DIR="${2:-${PROJECT_DIR}/pandoc_rhai/data/bin}"
CABAL_PROJECT="${PROJECT_DIR}/pandoc.cabal.project"
PANDOC_VERSION="3.9.0.2"

: "${GHC_PATH:?GHC_PATH env var must be set (directory containing ghc)}"
export PATH="${GHC_PATH}:${PATH}"

BUILD_CABAL="${BUILD_CABAL:-false}"
if [[ "${BUILD_CABAL,,}" == "true" ]]; then
    echo "=== BUILD_CABAL=true: bootstrapping cabal-install from source ==="
    CABAL_BOOTSTRAP_DIR="${CABAL_BOOTSTRAP_DIR:-${PROJECT_DIR}/cabal-bootstrap}"
    CABAL_OUTPUT_DIR="${PROJECT_DIR}/cabal-bin"
    "${SCRIPT_DIR}/build_cabal.sh" "${CABAL_BOOTSTRAP_DIR}" "${CABAL_OUTPUT_DIR}"
    CABAL_PATH="${CABAL_OUTPUT_DIR}"
else
    : "${CABAL_PATH:?CABAL_PATH env var must be set (directory containing cabal) or set BUILD_CABAL=true}"
fi
export PATH="${CABAL_PATH}:${PATH}"

if [[ ! -d "${HACKAGE_DIR}" ]]; then
    echo "Error: hackage packages directory not found: ${HACKAGE_DIR}" >&2
    echo "Run scripts/fetch_pandoc_deps.sh first" >&2
    exit 1
fi

HACKAGE_ABS="$(cd "${HACKAGE_DIR}" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

echo "=== Building pandoc ${PANDOC_VERSION} ==="
echo "GHC:     $(ghc --version)"
echo "Cabal:   $(cabal --version | head -1)"
echo "Packages: ${HACKAGE_ABS}"
echo "Build:    ${BUILD_DIR}"

mkdir -p "${BUILD_DIR}/.cabal"
cat > "${BUILD_DIR}/.cabal/config" << EOF
repository local-hackage
  url: file+noindex://${HACKAGE_ABS}

jobs: \$ncpus
installdir: ${BUILD_DIR}/install/bin
install-method: copy

library-stripping: True
executable-stripping: True
EOF
export CABAL_DIR="${BUILD_DIR}/.cabal"

cd "${BUILD_DIR}"
tar xf "${HACKAGE_ABS}/pandoc-cli-${PANDOC_VERSION}.tar.gz"
cd "pandoc-cli-${PANDOC_VERSION}"
cp "${CABAL_PROJECT}" cabal.project

# Index the local repository
cabal update

mkdir -p "${BUILD_DIR}/install/bin"
cabal build -v -j4 pandoc-cli

find "${BUILD_DIR}" -name pandoc -type f -executable -exec cp {} "${BUILD_DIR}/install/bin/" \;

"${BUILD_DIR}/install/bin/pandoc" --version

mkdir -p "${OUTPUT_DIR}"
cp "${BUILD_DIR}/install/bin/pandoc" "${OUTPUT_DIR}/pandoc"
echo "=== Pandoc binary: ${OUTPUT_DIR}/pandoc ==="
