# Pomodoro Bar - Agent Guidelines

This file provides instructions for AI agents working on the Pomodoro Bar codebase.

## Overview
Pomodoro Bar is a macOS menu bar application built with SwiftUI that implements the Pomodoro technique for time management.

## Project Structure
```
├── PomodoroBarApp.swift      # App entry, notification delegate
├── TimerModel.swift          # Business logic, state, notifications
├── TimerRingView.swift       # Animated progress ring
├── MenuBarView.swift         # Main UI, controls
├── SettingsView.swift        # Settings configuration
└── Assets.xcassets/          # Icons, colors
```

## Build & Install

**ALWAYS run this after making changes:**
```bash
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build && rm -rf /Applications/PomodoroBar.app && cp -R build/Build/Products/Debug/PomodoroBar.app /Applications/ && codesign --force --sign - --deep /Applications/PomodoroBar.app
```

## Build Commands

```bash
# Build for development
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build

# Build for release
xcodebuild -scheme PomodoroBar -configuration Release build CODE_SIGNING_ALLOWED=NO -derivedDataPath build

# Clean build
xcodebuild -scheme PomodoroBar -configuration Debug clean build CODE_SIGNING_ALLOWED=NO -derivedDataPath build
```

## Code Signing

**IMPORTANT**: Notifications require ad-hoc code signing. After building, sign the app:

```bash
codesign --force --sign - --deep /Applications/PomodoroBar.app
```

Full workflow for installing to Applications:
```bash
# Build
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build

# Copy and sign
rm -rf /Applications/PomodoroBar.app
cp -R build/Build/Products/Debug/PomodoroBar.app /Applications/
codesign --force --sign - --deep /Applications/PomodoroBar.app

# Run
open /Applications/PomodoroBar.app
```

Verify signing:
```bash
codesign --verify --verbose /Applications/PomodoroBar.app
```

**Note**: Without proper signing, notifications will not appear even if permission is granted. The app won't show in System Settings > Notifications until signed.

## Testing
No automated tests currently. When adding:
```bash
# Run all tests
xcodebuild -scheme PomodoroBar -configuration Debug test

# Run specific test
xcodebuild -scheme PomodoroBar -configuration Debug test -only-testing:TimerModelTests/testFocusDuration
```

## Code Style

### Imports
Order: SwiftUI, Foundation, AppKit, UserNotifications (one per line)

### Naming
- Types: PascalCase (`TimerModel`, `Phase`)
- Variables/functions: camelCase (`focusDuration`, `startTimer()`)
- Enums: singular, camelCase cases (`.focus`, `.shortBreak`)
- Booleans: prefixed with `is/has` (`isRunning`)

### SwiftUI Patterns
- Use `@MainActor @Observable` for models (macOS 14+)
- Computed properties for view sections (`private var header: some View`)
- Modifiers order: layout, visual, interaction, data
- Use `.foregroundStyle()` not `.foregroundColor()`
- 2-space indentation

### Model Patterns
- MARK sections: Timer State, Settings, Computed Properties, Controls, Phase Management, Notifications
- `TimeInterval` for time values (seconds as Double)
- `didSet` for side effects on property changes

### Notifications
- Delegate in `PomodoroBarApp.swift` via `NotificationDelegate`
- Check `authorizationStatus == .authorized` before adding notifications
- Use `.foreground` option on actions to bring app forward
- Default tap (no action button) should only activate app, not start timer

## Common Tasks

### Adding a Setting
1. Add property to `TimerModel` with default
2. Add `@State` in `SettingsView` init
3. Add UI in `durations` or `toggles`
4. Update `applyChanges()` in `SettingsView`

### Modifying Timer Logic
1. Edit `TimerModel.swift`
2. Ensure `@MainActor` for UI updates
3. Build and sign before testing notifications

## Notes
- No third-party dependencies
- The app is a `MenuBarExtra` with `.window` style
- `LSUIElement = YES` in Info.plist (menu bar only, no dock icon)
