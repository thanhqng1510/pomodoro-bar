#!/usr/bin/env bash
#
# Stamp a version into the app source so the built binary carries the release
# tag as its authoritative version. The git tag is the single source of truth:
# CI resolves the tag, then runs `set-version.sh <version>` right before
# xcodebuild. It rewrites both:
#   - AppVersion.swift            (read by the in-app updater)
#   - MARKETING_VERSION in project.pbxproj (powers the generated Info.plist)
#
# Usage:
#   ./set-version.sh v0.0.3
#   ./set-version.sh 0.0.3
#
set -euo pipefail

VERSION="${1:?usage: set-version.sh <version or tag like v0.0.1>}"
VERSION="${VERSION#v}"   # "v0.0.3" -> "0.0.3"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'invalid version: %s (expected something like 0.0.3)\n' "$VERSION" >&2
  exit 1
fi

# Rewrite MARKETING_VERSION in both Debug and Release configs.
PBX="PomodoroBar.xcodeproj/project.pbxproj"
if /usr/bin/sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${VERSION};/" "$PBX"; then
  printf 'stamped MARKETING_VERSION = %s in %s\n' "$VERSION" "$PBX"
fi

# Rewrite the version constant the updater reads.
SRC="AppVersion.swift"
if /usr/bin/sed -i '' "s/static let current = \"[^\"]*\"/static let current = \"${VERSION}\"/" "$SRC"; then
  printf 'stamped AppVersion.current = %s in %s\n' "$VERSION" "$SRC"
  grep -n 'static let current' "$SRC"
fi