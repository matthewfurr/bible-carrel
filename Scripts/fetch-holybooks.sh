#!/usr/bin/env bash
# Downloads the pinned holybooks commit (EN/ tree only) into the user cache.
# Prints the directory that contains EN/ on stdout. No-op when already present.
set -euo pipefail

SHA=0dab245f361980d2af3f4075cba3fbe8c4fa31b2
CACHE="${HOME}/Library/Caches/ReadingThroughScripture/holybooks"
DEST="${CACHE}/${SHA}"

if [ -f "${DEST}/EN/index.json" ]; then
  echo "${DEST}"
  exit 0
fi

mkdir -p "${CACHE}"
TMP="$(mktemp -d "${CACHE}/download.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

echo "Fetching holybooks ${SHA}…" >&2
curl -sSL "https://github.com/bobuk/holybooks/archive/${SHA}.tar.gz" -o "${TMP}/src.tar.gz"
mkdir -p "${TMP}/extract"
tar -xzf "${TMP}/src.tar.gz" -C "${TMP}/extract" --strip-components=1 "holybooks-${SHA}/EN"
mkdir -p "${DEST}"
mv "${TMP}/extract/EN" "${DEST}/EN"
echo "${DEST}"
