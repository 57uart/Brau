#!/bin/bash
# A first launch, without touching the browser you actually use.
#
#   ./fresh.sh          wipe the test world and open mnml as a newcomer
#   ./fresh.sh again    open the test copy as it was left, no wipe
#
#   MNML_PROBE=NAME ./fresh.sh   the same for a named world, "mnml (NAME)"
#
# A run with MNML_PROBE=1 keeps everything apart from the real one: its own
# folder under Application Support, its own settings suite, its own WebKit
# store for cookies and sign-ins. Wiping those three is a fresh install; the
# real session, pins, history and logins are never in reach of this script.
set -euo pipefail

cd "$(dirname "$0")"

# The world, named the way Store.world names it.
WORLD=$(printf '%s' "${MNML_PROBE:-test}" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-')
case "$WORLD" in ""|1) WORLD=test ;; esac
if [ "$WORLD" = test ]; then
  SUITE=com.farchan.mnml.test; HASH=0
else
  # Store.probeStore: FNV-1a of the name in the store's identifier.
  SUITE="com.farchan.mnml.test.$WORLD"; HASH=2166136261
  for ((i = 0; i < ${#WORLD}; i++)); do
    HASH=$(( ((HASH ^ $(printf '%d' "'${WORLD:i:1}")) * 16777619) & 0xFFFFFFFF ))
  done
fi
STORE=$(printf '5E4C%04X-%04X-4000-8000-000000000001' $((HASH >> 16)) $((HASH & 0xFFFF)))

if [ "${1:-}" != "again" ]; then
  rm -rf "$HOME/Library/Application Support/mnml ($WORLD)"
  defaults delete "$SUITE" 2>/dev/null || true
  # Store.probeStore(1), the fixed identifier of the world's website data.
  rm -rf "$HOME/Library/WebKit/com.farchan.mnml/WebsiteDataStore/$STORE"
  echo "world \"$WORLD\" wiped"
fi

[ -d "build/mnml.app" ] || ./build.sh release
open -n --env MNML_PROBE="$WORLD" "build/mnml.app"
