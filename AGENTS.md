# Pomodoro Bar - Agent Guidelines

## Overview
macOS menu bar Pomodoro timer app using SwiftUI and macOS 26 Liquid Glass.

## Project Structure
```
PomodoroBarApp.swift   # App entry, notification delegate
TimerModel.swift       # Business logic, state, notifications, UserDefaults persistence
TimerRingView.swift    # Animated progress ring, cycle dots
MenuBarView.swift      # Main UI, controls, settings
install.sh             # curl-based CLI installer (reuses release zip + checksums)
uninstall.sh           # CLI uninstaller
Assets.xcassets/       # Icons, phase colors, AccentColor
.github/workflows/     # CI: auto-build + release on tag push
```

## Distribution (install.sh)
- Users install via `curl -fsSL https://raw.githubusercontent.com/thanhqng1510/pomodoro-bar/main/install.sh | bash`
- Resolves latest version from the GitHub `releases/latest` API, falls back to `FALLBACK_VERSION`; arm64 only
- Downloads `PomodoroBar-<ver>.zip` + `checksums.txt` from the release, verifies SHA-256, installs to `/Applications`, ad-hoc signs
- Release uses `softprops/action-gh-release` with `draft: false` so the API + public download URLs work for the installer

## Build & Install
```bash
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build && rm -rf /Applications/PomodoroBar.app && cp -R build/Build/Products/Debug/PomodoroBar.app /Applications/ && codesign --force --sign - --deep /Applications/PomodoroBar.app
```

## Code Style
- **Imports**: SwiftUI, Foundation, AppKit, UserNotifications (one per line)
- **Naming**: PascalCase types, camelCase variables/functions, `is/has` prefix for booleans
- **SwiftUI**: `@MainActor @Observable` models, computed properties for views, `.foregroundStyle()`
- **Indentation**: 2 spaces

## Liquid Glass (macOS 26+)
- `GlassEffectContainer(spacing:)` wraps views for morphing transitions
- `.glassEffect(.regular, in: Shape)` for static surfaces
- `.glassEffect(.regular.interactive(), in: Shape)` for tappable elements
- `.glassEffectID("id", in: namespace)` with `@Namespace` for cross-view morphing
- **No shadows** - Liquid Glass has built-in depth
- **No glass on glass** - inside glass containers, use fills/transparency instead

## Notifications
- Categories registered once in `TimerModel.init()`
- Delegate in `PomodoroBarApp.swift`
- Check `authorizationStatus == .authorized` before adding
- Code signing required for notifications to work

## Settings Persistence
- Durations, long-break interval, notification toggle, and completed pomodoros persist via `UserDefaults` (see `TimerModel.Keys`)
- Deadline-based timer (`phaseEndDate`) — do not revert to tick-based countdown

## CI / Releases (`.github/workflows/release.yml`)
- Triggered by pushing a `v*` tag; two jobs: `build` (on `macos-26`) then `release` (`needs: build`, on `ubuntu-latest`)
- Build job: `xcodebuild -configuration Release` with `CODE_SIGNING_ALLOWED=NO`, zips `PomodoroBar.app` via `ditto`, writes a SHA-256 checksum, uploads as an artifact
- Release job: `softprops/action-gh-release@v2` attaches the zip + checksums and creates a draft release with auto-generated notes
- Version derives from the tag (`v0.0.1` → `0.0.1`); the build job overrides `MARKETING_VERSION` from the tag, so the built `CFBundleShortVersionString` always matches the tag (no manual project bump needed). A hard check fails the build if they ever diverge.
- App is unsigned/not notarized; Gatekeeper will warn first-time users until Developer ID/notarization is added

## Self-Update Rules
Update this file when:
- Files are created/deleted → update Project Structure
- Build scheme changes → update Build & Install
- New patterns/frameworks added → update Code Style
- New UI components → update Liquid Glass
- File purposes change → update descriptions