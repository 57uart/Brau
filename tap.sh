#!/bin/bash
# Points Homebrew at the version just released: the cask in
# github.com/57uart/homebrew-tap gets this version and the checksum of
# the disk image on its GitHub release, so that
#
#   brew install --cask 57uart/tap/search
#
# installs it, and brew upgrade brings it. Run it once the release is on
# GitHub (tag vX.Y.Z, Brau.dmg attached); it reads the version from VERSION.
set -euo pipefail

cd "$(dirname "$0")"
VERSION="$(tr -d '[:space:]' < VERSION)"
URL="https://github.com/57uart/Brau/releases/download/v$VERSION/Brau.dmg"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/Brau.dmg" "$URL" \
  || { echo "no Brau.dmg on the v$VERSION release yet — publish the release first" >&2; exit 1; }
SHA="$(shasum -a 256 "$WORK/Brau.dmg" | cut -d' ' -f1)"

git clone -q https://github.com/57uart/homebrew-tap.git "$WORK/tap"
CASK="$WORK/tap/Casks/search.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
if git -C "$WORK/tap" diff --quiet; then
  echo "the tap already has Brau $VERSION"
  exit 0
fi
git -C "$WORK/tap" commit -qam "Search $VERSION"
git -C "$WORK/tap" push -q
echo "tap: Brau $VERSION, sha256 $SHA"
