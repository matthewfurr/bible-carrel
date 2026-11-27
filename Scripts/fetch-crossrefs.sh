#!/usr/bin/env bash
# Downloads OpenBible.info's cross_references.txt (CC-BY, the 2026-09-21 file) and checks it against the pinned digest.
# Prints the cache directory holding cross_references.txt and cross_references.txt.sha256 on stdout. No-op when already
# present with the pinned digest; a cached text that no longer has it is fetched again.
set -euo pipefail

TEXT_SHA=d18f0cdee1fd9a0bb289e0c30154485857b396124f68fe0dcc37aaa5982644f8
# OpenBible replaces its file a few times a year; the mirror keeps the unmodified 2026-09-21 file. The mirror is
# named by commit (read with git ls-remote on 2026-11-18), not by a branch that can move.
URLS=(
  "https://a.openbible.info/data/cross-references.zip"
  "https://raw.githubusercontent.com/trekhleb/bible-cross-references/23bf0908858c949e519abe7a4ce7f4492f5fb3ba/data/raw/openbible-cross-references.zip"
)
MEMBER=cross_references.txt
# The text is about 8 MB; a member that runs past this is not it.
MAX_BYTES=67108864
CACHE="${HOME}/Library/Caches/ReadingThroughScripture/crossrefs"
DEST="${CACHE}/${TEXT_SHA:0:12}"

digest() { shasum -a 256 "$1" | cut -d' ' -f1; }

if [ -f "${DEST}/.complete" ]; then
  if [ -f "${DEST}/${MEMBER}" ] && [ "$(digest "${DEST}/${MEMBER}")" = "${TEXT_SHA}" ]; then
    echo "${DEST}"
    exit 0
  fi
  echo "The cached ${MEMBER} no longer has the pinned digest; fetching it again" >&2
fi

mkdir -p "${CACHE}"
TMP="$(mktemp -d "${CACHE}/download.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

found=""
for url in "${URLS[@]}"; do
  echo "Fetching ${url}…" >&2
  rm -f "${TMP}/zip" "${TMP}/text"
  if ! curl -fsSL --connect-timeout 20 --max-time 300 "${url}" -o "${TMP}/zip"; then
    echo "Could not download ${url}" >&2
    continue
  fi
  # The one member, read into a file and checked there: the archive is never unpacked.
  if ! unzip -p "${TMP}/zip" "${MEMBER}" 2>/dev/null | head -c "${MAX_BYTES}" > "${TMP}/text" || [ ! -s "${TMP}/text" ]; then
    echo "${url} holds no ${MEMBER}" >&2
    continue
  fi
  actual="$(digest "${TMP}/text")"
  if [ "${actual}" = "${TEXT_SHA}" ]; then
    found="${TMP}/text"
    break
  fi
  echo "${url} gave ${MEMBER} with digest ${actual}" >&2
done

if [ -z "${found}" ]; then
  echo "OpenBible changed ${MEMBER}; check it and re-pin the digest in fetch-crossrefs.sh" >&2
  exit 1
fi

rm -rf "${DEST}"
mkdir -p "${DEST}"
mv "${found}" "${DEST}/${MEMBER}"
echo "${TEXT_SHA}" > "${DEST}/${MEMBER}.sha256"
touch "${DEST}/.complete"
echo "${DEST}"
