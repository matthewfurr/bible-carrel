#!/usr/bin/env bash
# Rebuilds Build/bible.sqlite when it is missing or was built with an older schema.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="${ROOT}/Build/bible.sqlite"
# The schema the app reads: BibleSchema.version, read from its source so the two cannot drift.
SCHEMA="${ROOT}/Packages/ScriptureKit/Sources/ScriptureData/BibleSchema.swift"
WANT="$(sed -n 's/.*static let version = \([0-9][0-9]*\).*/\1/p' "${SCHEMA}")"
if [ -z "${WANT}" ]; then
  echo "Could not read BibleSchema.version from ${SCHEMA}" >&2
  exit 1
fi

if [ -f "${DB}" ] && [ "$(sqlite3 "${DB}" "SELECT value FROM meta WHERE key='schema_version'" 2>/dev/null || true)" = "${WANT}" ]; then
  exit 0
fi

bash "${ROOT}/Scripts/build-bible.sh"
