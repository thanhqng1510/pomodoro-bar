# Pomodoro Bar - Agent Guidelines

## Overview
macOS menu bar Pomodoro timer app using SwiftUI and macOS 26 Liquid Glass.

## Project Structure
```
PomodoroBarApp.swift   # App entry, notification delegate
TimerModel.swift       # Business logic, state, notifications
TimerRingView.swift    # Animated progress ring
MenuBarView.swift      # Main UI, controls, settings
Assets.xcassets/       # Icons, colors
```

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
- Delegate in `PomodoroBarApp.swift`
- Check `authorizationStatus == .authorized` before adding
- Code signing required for notifications to work

## Self-Update Rules
Update this file when:
- Files are created/deleted → update Project Structure
- Build scheme changes → update Build & Install
- New patterns/frameworks added → update Code Style
- New UI components → update Liquid Glass
- File purposes change → update descriptions