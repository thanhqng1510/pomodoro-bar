# Pomodoro Bar - Agent Guidelines

## Overview
macOS menu bar Pomodoro timer app using SwiftUI and macOS 26 Liquid Glass.

## Project Structure
```
PomodoroBarApp.swift   # App entry, NSApplicationDelegateAdaptor
AppDelegate.swift      # NotificationDelegate, popover management
TimerModel.swift       # Business logic, state, notifications, UserDefaults persistence
TimerRingView.swift    # Animated progress ring, cycle dots, scale animation on running state
MenuBarView.swift      # Main UI, controls, settings
Updater.swift          # In-app auto-updater: GitHub releases check, download, detach helper
AppVersion.swift       # Version constant, stamped from the release tag by set-version.sh
update.sh              # Detached swap helper used by Updater (SHA-256 verify, /Applications swap, relaunch)
set-version.sh         # Stamps a version/tag into AppVersion.swift + project.pbxproj (CI release)
install.sh             # curl-based CLI installer (reuses release zip + checksums)
uninstall.sh           # CLI uninstaller
Assets.xcassets/       # Icons, phase colors, AccentColor
.github/workflows/     # CI: auto-build + release on tag push
```

## In-App Auto-Update (Updater.swift + update.sh)
- Checks GitHub `releases/latest` on launch (cached to 1/day via `UserDefaults.lastUpdateCheckDate`) or on "Check for Updates…" (force); parses `tag_name` by string-scanning the JSON (no JSON decoder dependency), compares semver `a.b.c`
- On "Download": downloads `PomodoroBar-<ver>.zip` + `checksums.txt` to a temp work dir, writes an `update.manifest`, copies `update.sh` out of the bundle, makes it executable, then `NSApp.terminate`
- `update.sh` (detached via `posix_spawn` `POSIX_SPAWN_SETSID` — survives app exit): verifies SHA-256 against `checksums.txt` first (aborts with a status file on mismatch, nothing changed, relaunches app), waits for the app to quit, swaps `/Applications/PomodoroBar.app` via `mv` → `.old` + `ditto` (with graphical admin fallback via osascript and `codesign --force` ad-hoc, mirroring install.sh), runs `gktool scan` if present, relaunches via `open`
- Homebrew-cask guard: if `/opt/homebrew/Caskroom/pomodoro-bar` (or `~/Caskroom`) exists, detected preemptively in UI & in `update.sh` helper to redirect to `brew upgrade` (a self-swap would desync the Caskroom)
- Update UI (Settings): inline banner "New version vX.Y.Z available" with a circular download icon button that morphs into a progress spinner/% while downloading; states: checking / up-to-date / error (retry)
- `update.sh`'s `TARGET` is overridable via `PB_TARGET` env for tests

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
- **Imports**: SwiftUI, Foundation, AppKit, UserNotifications, Darwin (one per line)
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
- Delegate in `AppDelegate.swift`
- Check `authorizationStatus == .authorized` before adding
- Code signing required for notifications to work

## Settings Persistence
- Durations, long-break interval, and notification toggle persist via `UserDefaults` (see `TimerModel.Keys`); the in-cycle pomodoro count is memory-only and resets each cycle and on relaunch
- Deadline-based timer (`phaseEndDate`) — do not revert to tick-based countdown

## CI / Releases (`.github/workflows/release.yml`)
- Triggered by pushing a `v*` tag; two jobs: `build` (on `macos-26`) then `release` (`needs: build`, on `ubuntu-latest`)
- Build job: `xcodebuild -configuration Release` with `CODE_SIGNING_ALLOWED=NO`, zips `PomodoroBar.app` via `ditto`, writes a SHA-256 checksum, uploads as an artifact
- Release job: `softprops/action-gh-release@v2` attaches the zip + checksums and creates a draft release with auto-generated notes
- Version derives from the tag (`v0.0.1` → `0.0.1`); the build job runs `./set-version.sh "$VERSION"` before building, which stamps the version into `AppVersion.swift` (read by the updater) and `MARKETING_VERSION` in project.pbxproj (generates the Info.plist) — the tag is the single source of truth, no manual project bump needed. A hard check fails the build if the built `CFBundleShortVersionString` ever diverges from the tag.
- App is unsigned/not notarized; Gatekeeper will warn first-time users until Developer ID/notarization is added

## Self-Update Rules
Update this file when:
- Files are created/deleted → update Project Structure
- Build scheme changes → update Build & Install
- New patterns/frameworks added → update Code Style
- New UI components → update Liquid Glass
- File purposes change → update descriptions