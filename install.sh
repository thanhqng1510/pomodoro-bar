#!/usr/bin/env bash
#
# Install Pomodoro Bar from a GitHub Release, verify its checksum, and drop it
# into /Applications. Works with the artifacts produced by .github/workflows/
# release.yml: "PomodoroBar-<version>.zip" plus "checksums.txt".
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/thanhqng1510/pomodoro-bar/main/install.sh | bash
#
set -euo pipefail

REPO="thanhqng1510/pomodoro-bar"
APP_NAME="PomodoroBar"
# Fallback used only if the GitHub API is unavailable; the CI tag is the source
# of truth for published versions.
FALLBACK_VERSION="0.0.1"

# --- helpers ------------------------------------------------------------

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- resolve latest version --------------------------------------------

resolve_version() {
  local url="https://api.github.com/repos/${REPO}/releases/latest"
  local body
  if body=$(curl -fsSL -H "Accept: application/vnd.github+json" "$url" 2>/dev/null); then
    local tag
    tag=$(printf '%s' "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    if [[ -n "$tag" ]]; then
      printf '%s' "${tag#v}"   # v0.0.1 -> 0.0.1
      return
    fi
    warn "could not read tag from GitHub, using pinned version ${FALLBACK_VERSION}"
  else
    warn "GitHub API unavailable, using pinned version ${FALLBACK_VERSION}"
  fi
  printf '%s' "$FALLBACK_VERSION"
}

# --- arch guard ---------------------------------------------------------

expect_arm64() {
  local arch
  arch=$(uname -m)
  if [[ "$arch" != "arm64" ]]; then
    fail "This build only supports Apple Silicon (arm64). Detected: ${arch}."
  fi
}

# --- download + verify --------------------------------------------------

download() {
  local version="$1" url base
  base="https://github.com/${REPO}/releases/download/v${version}"
  url="${base}/PomodoroBar-${version}.zip"

  log "Downloading PomodoroBar ${version} ..."
  curl -fL --retry 3 -o "$TMP/app.zip" "$url"
  curl -fL --retry 3 -o "$TMP/checksums.txt" "${base}/checksums.txt"
}

verify_sha() {
  log "Verifying SHA-256 checksum ..."
  local expected
  expected=$(grep "PomodoroBar-.*\.zip" "$TMP/checksums.txt" | awk '{print $1}' | head -n1)
  [[ -n "$expected" ]] || fail "No checksum found for the app archive in checksums.txt."
  local actual
  actual=$(shasum -a 256 "$TMP/app.zip" | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    fail "Checksum mismatch. Expected ${expected}, got ${actual}. Aborting; nothing was changed."
  fi
  log "Checksum OK (${actual})"
}

# --- install ------------------------------------------------------------

install_app() {
  log "Installing to /Applications ..."
  local src sudo_cmd
  src=$(find "$TMP" -name "${APP_NAME}.app" -maxdepth 3 -type d | head -n1)
  [[ -n "$src" ]] || fail "Unzip produced no ${APP_NAME}.app"

  sudo_cmd=()
  if ! rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null ||
     ! ditto "$src" "/Applications/${APP_NAME}.app" 2>/dev/null; then
    # Some setups need admin to write to /Applications.
    sudo_cmd=(sudo -p "Password required to install into /Applications: ")
    rm -rf "/Applications/${APP_NAME}.app"
    "${sudo_cmd[@]}" ditto "$src" "/Applications/${APP_NAME}.app"
  fi
  codesign --force --sign - --deep "/Applications/${APP_NAME}.app" 2>/dev/null || \
    warn "Ad-hoc codesigning failed; the app may still launch."
}

# --- main ---------------------------------------------------------------

TMP=$(mktemp -d "${TMPDIR:-/tmp}/pb-install.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

expect_arm64
VERSION=$(resolve_version)
log "Pomodoro Bar v${VERSION}"

cd "$TMP"
download "$VERSION"
unzip -q app.zip
verify_sha

install_app
trap - EXIT
log "Done! Launch with: open -a ${APP_NAME}"