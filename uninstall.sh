#!/usr/bin/env bash
#
# Remove Pomodoro Bar and optionally its saved settings.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/thanhqng1510/pomodoro-bar/main/uninstall.sh | bash
#
set -euo pipefail

APP_NAME="PomodoroBar"
APP="/Applications/${APP_NAME}.app"
BUNDLE_ID="com.pomodoro-bar.app"

printf '\033[1;31mRemoving\033[0m %s\n' "$APP"

rm -rf "$APP" 2>/dev/null || sudo rm -rf "$APP"
if [[ -d "$APP" ]]; then
  echo "ERROR: could not remove ${APP}." >&2
  exit 1
fi
echo "Removed ${APP}."

read -r -p "Also delete saved settings? [y/N] " answer
if [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]; then
  defaults delete "$BUNDLE_ID" 2>/dev/null && echo "Settings deleted." || echo "No saved settings found."
fi

echo "Done."