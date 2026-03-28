# Pomodoro Bar - Agent Guidelines

This file provides instructions for AI agents working on the Pomodoro Bar codebase.

## Overview
Pomodoro Bar is a macOS menu bar application built with SwiftUI that implements the Pomodoro technique for time management.

## Project Structure
```
PomodoroBar/
├── PomodoroBarApp.swift      # App entry point
├── TimerModel.swift          # Business logic & state management
├── TimerRingView.swift       # Custom timer ring UI component
├── MenuBarView.swift         # Main menu bar interface
├── SettingsView.swift        # Settings configuration UI
└── Assets.xcassets/          # App icons and assets
```

## Build Commands

### Building the Application
```bash
# Build for debugging (recommended for development)
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Build for release
xcodebuild -scheme PomodoroBar -configuration Release build CODE_SIGNING_ALLOWED=NO

# Build to custom location (build/Debug/)
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build

# Clean build
xcodebuild -scheme PomodoroBar -configuration Debug clean build CODE_SIGNING_ALLOWED=NO -derivedDataPath build
```

### Running the Application
```bash
# After building, run the executable
open build/Build/Products/Debug/PomodoroBar.app

# Build and run in one step
xcodebuild -scheme PomodoroBar -configuration Debug build CODE_SIGNING_ALLOWED=NO -derivedDataPath build && open build/Build/Products/Debug/PomodoroBar.app
```

### Swift Compilation (Alternative)
For quick testing of individual files:
```bash
swiftc PomodoroBar/*.swift -o pomodoro -suppress-warnings
./pomodoro
```

## Testing
Currently, this project does not have automated tests implemented. When adding tests:

### Unit Testing Guidelines
- Use XCTest framework
- Test TimerModel business logic in isolation
- Mock dependencies where appropriate
- Focus on timer calculations, state transitions, and settings persistence

### Running Tests (When Implemented)
```bash
# Run all tests
xcodebuild -scheme PomodoroBar -configuration Debug test

# Run specific test class
xcodebuild -scheme PomodoroBar -configuration Debug test -only-testing:TimerModelTests

# Run specific test method
xcodebuild -scheme PomodoroBar -configuration Debug test -only-testing:TimerModelTests/testFocusDuration
```

## Code Style Guidelines

### Swift Language Version
- Swift 5.7+
- Prefer modern Swift concurrency (async/await) over completion handlers when appropriate
- Use `@MainActor` for UI-related code

### Import Organization
1. System frameworks (SwiftUI, Foundation, etc.)
2. Third-party frameworks (none currently)
3. Local imports (grouped by functionality)

```swift
// Correct order
import SwiftUI
import Foundation
import AppKit
import UserNotifications
import AVFoundation

// Local imports (if any)
import CustomFramework
```

### File Structure
Each Swift file should follow this structure:
1. Import statements
2. Type definitions (enums, structs, classes)
3. Extensions (separated by functionality)
4. Private methods at the end

### Naming Conventions
- **Types** (struct, class, enum): PascalCase (e.g., `TimerModel`, `Phase`)
- **Variables & Constants**: camelCase (e.g., `focusDuration`, `isRunning`)
- **Functions**: camelCase (e.g., `startTimer()`, `resetToPhase()`)
- **Enums**: PascalCase with singular names (e.g., `Phase`, not `Phases`)
- **Enum Cases**: camelCase (e.g., `.focus`, `.shortBreak`)
- **Properties**: Descriptive, boolean properties prefixed with `is/has` (e.g., `isRunning`, `hasCompleted`)

### SwiftUI Specific Guidelines
#### View Organization
- Break complex views into smaller, reusable subviews
- Use computed properties for view components (`private var header: some View { ... }`)
- Prefer `some View` return types for computed view properties
- Use descriptive names for view components

#### Modifiers
- Apply modifiers in logical order:
  1. Layout-modifying modifiers (padding, frame, offset)
  2. Visual modifiers (background, foregroundStyle, opacity)
  3. Interaction modifiers (gesture, onTapGesture)
  4. Data-modifying modifiers (onAppear, onChange)

#### State Management
- Use `@State` for view-local state
- Use `@Binding` for state shared between views
- Use `@ObservedObject` or `@EnvironmentObject` for shared data models
- Prefer `@Observable` (iOS 17+) or `@StateObject` for model objects

### Code Formatting
- Indentation: 2 spaces (Swift standard)
- Line length: Aim for < 100 characters when possible
- Empty lines: Use to separate logical sections
- Trailing commas: Use in multi-line arrays, dictionaries, and function parameters
- Operator spacing: Add spaces around operators (`let x = a + b`, not `let x =a+b`)

### Specific Patterns Used in This Codebase

#### TimerModel Patterns
- Use `@MainActor @Observable` for state management (iOS 17+/macOS 14+)
- Group related properties with `// MARK:` comments
- Use `didSet` observers for properties that require side effects when changed
- Keep timer logic separate from UI concerns
- Use `TimeInterval` for time values (seconds as Double)

#### View Patterns
- Use `GlassEffectContainer` for consistent UI styling (defined elsewhere)
- Use `HStack`/`VStack`/`ZStack` for layout with explicit spacing
- Use `Spacer()` for flexible layout
- Use `Image(systemName:)` for SF Symbols
- Apply consistent sizing for icons (typically 10-14pt font size)
- Use `.font(.system(size:weight:design:))` for precise typography control

#### Button Patterns
- For icon-only buttons: Provide adequate touch target (minimum 44x44 pts)
- Use `.frame(width:height:)` to increase tappable area when needed
- Prefer `.buttonStyle(.plain)` for custom styled buttons
- Use `.foregroundStyle()` for color instead of deprecated `.foregroundColor()`
- For text+icon buttons: Use `HStack` with spacing inside button label

### Error Handling
- Use Swift's error handling (`throw`, `try`, `do-catch`) for recoverable errors
- For unrecoverable conditions, use `assertionFailure()` or `preconditionFailure()` during development
- Handle optional values with `guard let` or `if let` rather than force unwrapping (`!`)
- For UserNotifications and AVFoundation, handle permission denial gracefully

### Specific File Guidelines

#### TimerModel.swift
- Keep all timer logic in this file
- Use `@Published` properties for observable state (if not using `@Observable`)
- Separate MARK sections for: Timer State, Settings, Computed Properties, Controls, Phase Management, Sound, Notifications
- Use private methods for internal logic
- Keep public API minimal and clear

#### View Files (SettingsView.swift, MenuBarView.swift, etc.)
- Keep UI logic only; delegate business logic to TimerModel
- Use private computed properties for view sections
- Group related UI elements with appropriate spacing
- Use accessibility labels where meaningful
- Apply consistent padding (typically 20px for main containers)

### Git Practices
- Commit frequently with descriptive messages
- Use present tense in commit messages ("Add feature" not "Added feature")
- Reference relevant issues or tickets in commit messages when applicable
- Keep changes focused; avoid mixing unrelated modifications in one commit

### Third-Party Dependencies
Currently, this project uses no third-party dependencies. If adding any:
- Use Swift Package Manager
- Document purpose in Package.swift comments
- Ensure compatibility with minimum deployment target
- Update .gitignore as needed

### Accessibility
- Add accessibility labels to custom controls
- Ensure sufficient color contrast
- Support Dynamic Type where appropriate (though limited in menu bar apps)
- Provide meaningful accessibility hints

### Performance
- Avoid expensive computations in body properties
- Use `@State` judiciously to minimize view updates
- Cancel timers and tasks when appropriate (observe lifecycle)
- Keep observation granular (only observe what's needed)

## Common Tasks

### Adding a New Setting
1. Add property to TimerModel with appropriate default
2. Add didSet observer if UI needs immediate update
3. Add corresponding State property in SettingsView
4. Add UI row in durations or toggles section
5. Update applyChanges() to copy value to model
6. Initialize State property in init()

### Modifying Timer Logic
1. Make changes to TimerModel methods
2. Ensure thread safety (use @MainActor where needed)
3. Update any dependent computed properties
4. Test state transitions thoroughly
5. Verify sound/notifications still work correctly

### Changing UI Appearance
1. Modify view files (MenuBarView, SettingsView, etc.)
2. Keep changes consistent with existing styling patterns
3. Test at different window sizes if applicable
4. Verify accessibility isn't compromised
5. Check that custom button styles still work
