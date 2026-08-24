# Pomodoro Bar

A minimal macOS menu bar Pomodoro timer built with SwiftUI.

## Features

- **Menu bar timer** - Lives in your menu bar, always accessible
- **Pomodoro technique** - Focus sessions with short and long breaks
- **Progress ring** - Visual animated progress indicator
- **Customizable durations** - Configure focus, short break, and long break times
- **Notifications** - macOS notifications when phases complete
- **Quick controls** - Start, pause, reset, and skip from the menu bar
- **Persistent settings** - Durations and preferences are saved between launches
- **Cycle tracking** - Dots show your progress toward the long break
- **Auto-update** - Checks GitHub for new releases (once a day), shows an "Update available" banner in Settings with a one-click Download that verifies the SHA-256 checksum before replacing the app

## Screenshots

![Timer view](timer-view.png)
![Settings view](settings-view.png)

## Requirements

- macOS 26.0+ (Liquid Glass)
- Xcode 26.0+ (to build from source)

## Install

The easiest way to install is with a single command from a terminal (macOS 26,
Apple Silicon):

```bash
curl -fsSL https://raw.githubusercontent.com/thanhqng1510/pomodoro-bar/main/install.sh | bash
```

This downloads the latest release, verifies its checksum, and installs it to
`/Applications`. Launch it with:

```bash
open -a PomodoroBar
```

To uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/thanhqng1510/pomodoro-bar/main/uninstall.sh | bash
```

> Currently only **Apple Silicon (arm64)** builds are published. Intel Macs
> aren't supported yet.

## Build & Install

```bash
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build && \
rm -rf /Applications/PomodoroBar.app && \
cp -R build/Build/Products/Debug/PomodoroBar.app /Applications/ && \
codesign --force --sign - --deep /Applications/PomodoroBar.app
```

Then open from Applications or run:
```bash
open /Applications/PomodoroBar.app
```

## Publishing a Release

Releases are automated with GitHub Actions. Pushing a version tag builds the
app on a GitHub-hosted macOS runner, then creates a GitHub Release with the
app binary and auto-generated release notes attached. The tag is the single
source of truth — `set-version.sh` stamps it into both the version constant the
updater reads and the app's Info.plist during the build.

1. Commit and push your changes, then create and push a version tag:

   ```bash
   git tag v0.0.1
   git push origin refs/tags/v0.0.1
   ```

   The `refs/tags/` prefix makes it explicit that you're pushing the tag, so
   it can't be confused with a branch of the same name.

2. The workflow runs in **Actions**: the build job stamps the version from the
   tag, compiles the app (a hard check fails if the built version doesn't match
   the tag), and uploads it; then a release job creates and **publishes** the
   release on the
   [Releases](https://github.com/thanhqng1510/pomodoro-bar/releases) page
   with auto-generated notes. Because releases publish automatically, review
   the tag and changelog **before** pushing it.

Each release automatically includes the **source code** (a zip/tar.gz archive)
and the built `PomodoroBar-v<ver>.zip` plus a `checksums.txt` file. Because the
app is not notarized, first-time users on macOS will see an "unidentified
developer" warning and must right-click → **Open** to launch it.

## Default Settings

| Setting | Duration |
|---------|----------|
| Focus | 25 min |
| Short Break | 5 min |
| Long Break | 15 min |
| Long Break After | 4 pomodoros |

## Project Structure

```
PomodoroBarApp.swift   - App entry point, notification delegate
TimerModel.swift       - Timer logic, state management, notifications
TimerRingView.swift    - Animated circular progress ring
MenuBarView.swift      - Main UI with controls and settings
install.sh             - curl-based CLI installer
uninstall.sh           - CLI uninstaller
Assets.xcassets/       - App icons, accent colors, phase colors
```

## License

MIT
