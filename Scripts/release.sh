#!/bin/bash
#
# release.sh <version>
#
# Cuts a Shed release end to end:
#   1. builds a universal .dmg (via package-and-notarize.sh — honors
#      DEVELOPER_ID / NOTARY_PROFILE if set, otherwise ad-hoc),
#   2. creates/updates the GitHub release and uploads the dmg,
#   3. bumps version + sha256 in the Homebrew tap cask and pushes it,
#   4. updates the in-repo cask, landing page, and beta notes, and commits.
#
# Usage:
#   ./Scripts/release.sh 1.0.0-beta.2
#
# Optional env:
#   DEVELOPER_ID / NOTARY_PROFILE  → notarized build (see package-and-notarize.sh)
#   TAP_REPO                       → default willdickerson/homebrew-tap
#   REPO                           → default willdickerson/shed

set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
[ -n "$NEW" ] || { echo "usage: ./Scripts/release.sh <version>   e.g. 1.0.0-beta.2" >&2; exit 1; }
REPO="${REPO:-willdickerson/shed}"
TAP_REPO="${TAP_REPO:-willdickerson/homebrew-tap}"
DMG="dist/Shed-$NEW.dmg"

# Current version (used to rewrite version strings in docs).
OLD="$(sed -nE 's/^  version "(.*)"/\1/p' Casks/shed.rb | head -1)"
echo "→ Releasing $NEW (previous: ${OLD:-none})"

# 1. Build the dmg.
./Scripts/package-and-notarize.sh "$NEW"
[ -f "$DMG" ] || { echo "error: $DMG was not produced" >&2; exit 1; }
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "→ sha256: $SHA"

# 2. Update in-repo version strings + cask, so release notes are current.
if [ -n "$OLD" ]; then
  for f in BETA.md docs/index.html Casks/shed.rb; do
    LC_ALL=C sed -i '' "s|$OLD|$NEW|g" "$f"
  done
fi
LC_ALL=C sed -i '' -E "s|^  sha256 \".*\"|  sha256 \"$SHA\"|" Casks/shed.rb

# 3. GitHub release (create or refresh).
if gh release view "v$NEW" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "v$NEW" "$DMG" --repo "$REPO" --clobber
else
  gh release create "v$NEW" "$DMG" --repo "$REPO" \
    --title "Shed $NEW" --notes-file BETA.md --prerelease
fi

# 4. Bump the Homebrew tap cask.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git clone -q "https://github.com/$TAP_REPO.git" "$TMP/tap"
CASK="$TMP/tap/Casks/shed.rb"
LC_ALL=C sed -i '' -E \
  -e "s|^  version \".*\"|  version \"$NEW\"|" \
  -e "s|^  sha256 \".*\"|  sha256 \"$SHA\"|" "$CASK"
if ! git -C "$TMP/tap" diff --quiet; then
  git -C "$TMP/tap" commit -aqm "Shed $NEW"
  git -C "$TMP/tap" push -q
  echo "→ Tap updated."
else
  echo "→ Tap already current."
fi

# 5. Commit the in-repo changes.
git add -A
if ! git diff --cached --quiet; then
  git commit -qm "Release $NEW"
  git push -q origin main
  echo "→ Repo updated and pushed."
fi

echo
echo "✓ Released Shed $NEW"
echo "  Release: https://github.com/$REPO/releases/tag/v$NEW"
echo "  Testers update with: brew update && brew upgrade --cask shed"
