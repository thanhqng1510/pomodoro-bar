#!/usr/bin/env bash
#
# Detached update helper for Pomodoro Bar. The app stages the new release and
# this script beside it, then this script verifies the checksum, swaps the new
# .app into /Applications, and relaunches. It survives the app quitting, so the
# running bundle can be replaced.
#
# Writes a small status file so any leftover state is inspectable, and never
# touches a Homebrew cask install (see Handoff): if the app was installed from
# a cask, the Caskroom receipt would desync, so we bail to a `brew upgrade`
# hint instead.
#
set -euo pipefail

WORKDIR="$(dirname "$0")"
APP_NAME="PomodoroBar"
TARGET="${PB_TARGET:-/Applications/${APP_NAME}.app}"   # overridable for tests
MANIFEST="${WORKDIR}/update.manifest"
STATUS="${WORKDIR}/update.status"

log() { printf '[updater] %s\n' "$*"; }
fail() { printf '[updater] ERROR: %s\n' "$*" >&2; echo "failed: $*" > "$STATUS"; exit 1; }

version=""
if [[ -f "$MANIFEST" ]]; then
  version=$(grep -E '^version=' "$MANIFEST" | head -1 | sed 's/^version=//')
fi
[[ -n "$version" ]] || fail "no version in update.manifest"
NEW_APP="${WORKDIR}/${APP_NAME}.app"
ZIP="${WORKDIR}/${APP_NAME}-${version}.zip"

# --- Homebrew-cask guard: never self-swap a brew-installed copy ----------
for caskroom in /opt/homebrew/Caskroom ~/Caskroom; do
  if [[ -d "$caskroom/pomodoro-bar" ]]; then
    fail "installed via Homebrew — run 'brew upgrade pomodoro-bar' instead"
  fi
done

# --- wait for the running app to fully exit -----------------------------
for _ in $(seq 1 150); do   # up to 15s
  [[ -z "$(pgrep -x "${APP_NAME}" 2>/dev/null)" ]] && break
  sleep 0.1
done

# --- verify checksum (blocking is fine: we're the only writer) ---------
if [[ -f "${WORKDIR}/checksums.txt" ]]; then
  expected=$(grep "${APP_NAME}-.*\.zip" "${WORKDIR}/checksums.txt" | awk '{print $1}' | head -1)
  if [[ -n "$expected" ]]; then
    actual=$(shasum -a 256 "$ZIP" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
      fail "checksum mismatch (expected ${expected}, got ${actual})"
    fi
  fi
fi

# --- unzip if needed, swap, relaunch ------------------------------------
[[ -d "$NEW_APP" ]] || ditto -x -k "$ZIP" "$WORKDIR"
[[ -d "$NEW_APP" ]] || fail "no ${APP_NAME}.app inside ${WORKDIR}"

# Replace /Applications copy (admin fallback mirrors install.sh)
replace_app() {
  rm -rf "${TARGET}.old"
  if [[ -d "$TARGET" ]]; then mv "$TARGET" "${TARGET}.old"; fi
  ditto "$NEW_APP" "$TARGET"
  codesign --force --sign - --deep "$TARGET" 2>/dev/null || true
}
if ! replace_app; then
  sudo -p "Password required to update ${APP_NAME} in /Applications: " sh -c \
    'rm -rf "/Applications/'"${APP_NAME}"'.old"; mv "/Applications/'"${APP_NAME}"'.app" "/Applications/'"${APP_NAME}"'.old"; ditto '"'$NEW_APP'"' "/Applications/'"${APP_NAME}"'.app"' \
    && codesign --force --sign - --deep "$TARGET" 2>/dev/null || fail "could not replace app"
fi

# Pre-warm Gatekeeper so the relaunched app isn't stuck on "Verifying…".
if [[ -x /usr/bin/gktool ]]; then gktool scan "$TARGET" 2>/dev/null; fi

printf "applied: %s\n" "$version" > "$STATUS"
rm -rf "${TARGET}.old" || true

open "$TARGET"