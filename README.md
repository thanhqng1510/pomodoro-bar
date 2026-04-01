# Pomodoro Bar

A minimal macOS menu bar Pomodoro timer built with SwiftUI.

## Features

- **Menu bar timer** - Lives in your menu bar, always accessible
- **Pomodoro technique** - Focus sessions with short and long breaks
- **Progress ring** - Visual animated progress indicator
- **Customizable durations** - Configure focus, short break, and long break times
- **Notifications** - macOS notifications when phases complete
- **Quick controls** - Start, pause, reset, and skip from the menu bar

## Requirements

- macOS 26.0+ (Liquid Glass)
- Xcode 16.0+

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
Assets.xcassets/       - App icons, accent colors, phase colors
```

## License

MIT
