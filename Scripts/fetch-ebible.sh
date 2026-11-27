#!/usr/bin/env bash
# Downloads the pinned eBible BSB and KJV USFM zips into the user cache.
# Prints the directory that contains engbsb_usfm/ and eng-kjv_usfm/ on stdout. No-op when already present.
set -euo pipefail

BSB_SHA=75ca91d5a5c69ca4cbdeabdb03ea1a458db20cf3966abe15d86df086acf7fbc4
KJV_SHA=941ef56e3e38a5cd7d72a2ea582559e37e9da5be0b241cf8caf71014650b8133
CACHE="${HOME}/Library/Caches/ReadingThroughScripture/ebible"
DEST="${CACHE}/${BSB_SHA:0:12}-${KJV_SHA:0:12}"

if [ -f "${DEST}/.complete" ]; then
  echo "${DEST}"
  exit 0
fi

mkdir -p "${CACHE}"
TMP="$(mktemp -d "${CACHE}/download.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

fetch() { # <zip name> <folder> <sha256>
  local url="https://ebible.org/Scriptures/$1"
  echo "Fetching eBible $1…" >&2
  if ! curl -fsSL "${url}" -o "${TMP}/$1"; then
    echo "Could not download ${url}; check the connection or whether eBible moved it" >&2
    exit 1
  fi
  local actual
  actual="$(shasum -a 256 "${TMP}/$1" | cut -d' ' -f1)"
  if [ "${actual}" != "$3" ]; then
    echo "eBible changed $1; check it and re-pin the digest in fetch-ebible.sh" >&2
    exit 1
  fi
  mkdir -p "${TMP}/out/$2"
  unzip -q "${TMP}/$1" -d "${TMP}/out/$2"
  echo "$3" > "${TMP}/out/$2.sha256"
}

fetch engbsb_usfm.zip engbsb_usfm "${BSB_SHA}"
fetch eng-kjv_usfm.zip eng-kjv_usfm "${KJV_SHA}"

rm -rf "${DEST}"
mkdir -p "${DEST}"
mv "${TMP}/out/"* "${DEST}/"
touch "${DEST}/.complete"
echo "${DEST}"
