#!/usr/bin/env bash
# Builds Build/bible.sqlite from the pinned holybooks source.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHA=0dab245f361980d2af3f4075cba3fbe8c4fa31b2
OUT="${ROOT}/Build/bible.sqlite"

# Prefer a full Xcode toolchain when xcode-select still points at the Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ] && ! xcode-select -p | grep -q "Xcode.app"; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SRC="$(bash "${ROOT}/Scripts/fetch-holybooks.sh")"
EBIBLE="$(bash "${ROOT}/Scripts/fetch-ebible.sh")"
CROSSREFS="$(bash "${ROOT}/Scripts/fetch-crossrefs.sh")"
THEOGRAPHIC="$(bash "${ROOT}/Scripts/fetch-theographic.sh")"
mkdir -p "${ROOT}/Build"

swift run -c release --package-path "${ROOT}/Packages/ScriptureKit" bible-importer \
  --source "${SRC}" --output "${OUT}" --commit "${SHA}" --ebible "${EBIBLE}" \
  --crossrefs "${CROSSREFS}/cross_references.txt" --theographic "${THEOGRAPHIC}"

echo "${OUT} ($(du -h "${OUT}" | cut -f1))"
