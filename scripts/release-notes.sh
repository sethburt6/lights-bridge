#!/bin/bash
# Prints the GitHub release page text for a version: that version's CHANGELOG section,
# then docs/RELEASE_NOTES.md (the install instructions).
# Usage: scripts/release-notes.sh 1.0.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

VERSION="${1:?usage: release-notes.sh VERSION}"
BODY="$(awk -v v="$VERSION" '
  /^## \[/ { if (on) exit; on = (index($0, "## [" v "]") == 1); next }
  on { print }
' CHANGELOG.md)"

if [[ -z "$(printf '%s' "$BODY" | tr -d '[:space:]')" ]]; then
  echo "error: no section for version $VERSION in CHANGELOG.md" >&2
  exit 1
fi

echo "## What's new in $VERSION"
printf '%s\n' "$BODY"
echo
cat docs/RELEASE_NOTES.md
