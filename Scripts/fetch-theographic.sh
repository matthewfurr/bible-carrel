#!/usr/bin/env bash
# Downloads five tables of Theographic Bible Metadata (CC BY-SA 4.0) at one pinned commit and checks each against its
# pinned digest. Prints the cache directory holding books.json, people.json, places.json, events.json, verses.json,
# `commit` and `.complete` on stdout. No-op when already complete with every digest right.
set -euo pipefail

COMMIT=b9a84854369502d10cdc7086e58e2794dbfd6722
BASE="https://raw.githubusercontent.com/robertrouse/theographic-bible-metadata/${COMMIT}/json"
# file:digest, each file's SHA-256 at the pinned commit.
FILES=(
  "books.json:a3ed9fc30b0d12c01f5259a8e8e793e3afdfa63ae2d51ad18bb82d5e630878a9"
  "people.json:031d5f7f662bba093fb712243d17182925289eaf420e2490ba606bf71600448a"
  "places.json:577b654f3f2c5867b7502aec647c039c53f8a0477971a2d913be04a873fcad7c"
  "events.json:cfff452550897d4ec3bc622179d680a3463146aec5ba5bf46359f1b1d6bd0e31"
  "verses.json:db9fe10c996720d5b9c1dcd02caf1c4b3c1ebf17810e98af59be794e0038c58d"
)
# The largest table is about 36 MB; a file that runs past this is not it.
MAX_BYTES=134217728
CACHE="${HOME}/Library/Caches/ReadingThroughScripture/theographic"
DEST="${CACHE}/${COMMIT:0:12}"

digest() { shasum -a 256 "$1" | cut -d' ' -f1; }

complete() {
  [ -f "${DEST}/.complete" ] || return 1
  local entry
  for entry in "${FILES[@]}"; do
    [ -f "${DEST}/${entry%%:*}" ] && [ "$(digest "${DEST}/${entry%%:*}")" = "${entry#*:}" ] || return 1
  done
}

if complete; then
  echo "${DEST}"
  exit 0
fi
if [ -f "${DEST}/.complete" ]; then
  echo "The cached Theographic tables no longer have the pinned digests; fetching them again" >&2
fi

mkdir -p "${CACHE}"
TMP="$(mktemp -d "${CACHE}/download.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

for entry in "${FILES[@]}"; do
  file="${entry%%:*}"
  want="${entry#*:}"
  echo "Fetching ${BASE}/${file}…" >&2
  if ! curl -fsSL --connect-timeout 20 --max-time 600 "${BASE}/${file}" | head -c "${MAX_BYTES}" > "${TMP}/${file}" || [ ! -s "${TMP}/${file}" ]; then
    echo "Could not download ${BASE}/${file}" >&2
    exit 1
  fi
  if [ "$(digest "${TMP}/${file}")" != "${want}" ]; then
    echo "Theographic's ${file} is not the pinned one; check it and re-pin fetch-theographic.sh" >&2
    exit 1
  fi
done

rm -rf "${DEST}"
mkdir -p "${DEST}"
for entry in "${FILES[@]}"; do
  mv "${TMP}/${entry%%:*}" "${DEST}/${entry%%:*}"
done
echo "${COMMIT}" > "${DEST}/commit"
touch "${DEST}/.complete"
echo "${DEST}"
