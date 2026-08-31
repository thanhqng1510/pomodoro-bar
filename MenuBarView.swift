import SwiftUI
import UserNotifications
import AppKit

struct MenuBarView: View {
  @Bindable var model: TimerModel
  @State private var showSettings = false
  @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
  @Namespace private var glassNamespace

  var body: some View {
    VStack(spacing: 0) {
      GlassEffectContainer(spacing: 12) {
        header
      }
      contentView
    }
    .frame(width: 260)
    .onAppear {
      Task { await checkNotificationPermission() }
      model.updater.checkForUpdates()
    }
  }

  // MARK: - Header
  private var header: some View {
    HStack {
      headerButton
      Spacer()
      exitButton
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private var headerButton: some View {
    ZStack {
      Button {
        withAnimation(.bouncy) {
          showSettings.toggle()
        }
      } label: {
        Image(systemName: showSettings ? "chevron.left" : "slider.horizontal.3")
          .font(.system(size: 14))
          .frame(width: 32, height: 32)
          .contentShape(Circle())
      }
      .buttonStyle(.borderless)
      .glassEffect(.regular.interactive(), in: Circle())
      .glassEffectID("left", in: glassNamespace)
      .accessibilityLabel(headerButtonLabel)
      .help(headerButtonLabel)

      if !showSettings, model.updater.state == .available {
        Circle()
          .fill(Color.accentColor)
          .frame(width: 7, height: 7)
          .offset(x: 11.3, y: -11.3)
          .allowsHitTesting(false)
          .zIndex(10)
      }
    }
  }

  private var headerButtonLabel: String {
    if showSettings {
      return "Back to timer"
    } else if model.updater.state == .available {
      return "Settings (Update available)"
    } else {
      return "Settings"
    }
  }

  @ViewBuilder
  private var exitButton: some View {
    if !showSettings {
      Button { NSApp.terminate(nil) } label: {
        Image(systemName: "power")
          .font(.system(size: 14))
          .frame(width: 32, height: 32)
          .contentShape(Circle())
      }
      .buttonStyle(.borderless)
      .glassEffect(.regular.interactive(), in: Circle())
      .glassEffectID("exit", in: glassNamespace)
      .accessibilityLabel("Quit Pomodoro Bar")
      .help("Quit Pomodoro Bar")
    }
  }

  // MARK: - Content
  @ViewBuilder
  private var contentView: some View {
    ZStack {
      if showSettings {
        settingsContent
          .transition(.opacity)
      } else {
        mainContent
          .transition(.opacity)
      }
    }
  }

  private var mainContent: some View {
    VStack(spacing: 12) {
      TimerRingView(
        progress: model.progress,
        phase: model.phase,
        sessionLabel: model.sessionLabel,
        timeText: model.menuBarTitle,
        isRunning: model.isRunning,
        onToggle: { model.toggle() }
      )
      CycleDotsView(
        completed: model.completedInCycle,
        total: model.longBreakInterval,
        color: model.phase.color
      )
      controlButtons
    }
    .padding(.horizontal, 16)
    .padding(.top, 2)
    .padding(.bottom, 14)
  }

  private var settingsContent: some View {
    VStack(spacing: 10) {
      updateBanner
      durationsSection
      toggleSection
      permissionButton
    }
    .padding(.horizontal, 16)
    .padding(.top, 2)
    .padding(.bottom, 14)
  }

  // MARK: - Update UI
  @ViewBuilder
  private var updateBanner: some View {
    switch model.updater.state {
    case .available, .downloading, .updating:
      HStack(alignment: .center, spacing: 8) {
        Image(systemName: "sparkles")
          .font(.system(size: 13))
          .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 2) {
          Text(bannerTitle)
            .font(.system(size: 11, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
          if !model.updater.error.isEmpty {
            Text(model.updater.error)
              .font(.system(size: 10))
              .foregroundStyle(.red)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button {
          model.updater.applyUpdate()
        } label: {
          updateButtonLabel
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.1), in: Circle())
        .accessibilityLabel(model.updater.isHomebrew ? "Manage with Homebrew" : "Update to v\(model.updater.latestVersion)")
        .help(model.updater.isHomebrew ? "Manage with Homebrew" : "Update to v\(model.updater.latestVersion)")
        .disabled(model.updater.state == .downloading || model.updater.state == .updating)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 10)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    case .checking:
      HStack(spacing: 8) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 10))
        Text("Checking for updates…")
          .font(.system(size: 11))
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 10)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    case .upToDate:
      rowStatus("Up to date (v\(model.updater.currentVersion))", "checkmark.circle")
    case .idle, .error:
      if !model.updater.error.isEmpty {
        rowStatus(model.updater.error, "exclamationmark.triangle")
      }
    }
  }

  private var bannerTitle: String {
    if model.updater.isHomebrew {
      return "Update v\(model.updater.latestVersion) available via brew."
    }
    switch model.updater.state {
    case .downloading:
      return "Downloading v\(model.updater.latestVersion) (\(Int(model.updater.progress * 100))%)"
    case .updating:
      return "Installing v\(model.updater.latestVersion)"
    default:
      return "New version v\(model.updater.latestVersion) available."
    }
  }

  @ViewBuilder
  private var updateButtonLabel: some View {
    let u = model.updater
    if u.isHomebrew {
      Image(systemName: "terminal")
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    } else if u.state == .downloading || u.state == .updating {
      ProgressView()
        .controlSize(.small)
        .frame(width: 28, height: 28)
    } else {
      Image(systemName: "arrow.down.circle.fill")
        .font(.system(size: 16))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
  }

  @ViewBuilder
  private func rowStatus(_ text: String, _ icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      Text(text)
        .font(.system(size: 11))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        model.updater.checkForUpdates(force: true)
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11, weight: .medium))
          .frame(width: 24, height: 24)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .background(Color.primary.opacity(0.08), in: Circle())
      .accessibilityLabel("Check for updates")
      .help("Check for updates")
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 10)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Control Buttons
  private var controlButtons: some View {
    HStack(spacing: 0) {
      controlButton(icon: "arrow.counterclockwise", label: "Reset session", action: model.reset)
      controlButton(
        icon: model.isRunning ? "pause.fill" : "play.fill",
        label: model.isRunning ? "Pause" : "Start",
        action: model.toggle,
        isPrimary: true,
        shortcut: .space
      )
      controlButton(icon: "forward.end.fill", label: "Skip to next phase", action: model.skip)
    }
    .glassEffect(.regular.interactive(), in: Capsule())
  }

  private func controlButton(
    icon: String,
    label: String,
    action: @escaping () -> Void,
    isPrimary: Bool = false,
    shortcut: KeyEquivalent? = nil
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: isPrimary ? 18 : 14))
        .frame(width: isPrimary ? 56 : 48, height: 40)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .modifier(KeyboardShortcutModifier(shortcut: shortcut))
    .accessibilityLabel(label)
    .help(label)
  }

  // MARK: - Settings
  private var durationsSection: some View {
    VStack(spacing: 4) {
      SettingNumberField(
        label: "Focus", icon: "brain.head.profile",
        value: $model.focusDuration, range: 1...120, unit: "min"
      )
      SettingNumberField(
        label: "Short Break", icon: "cup.and.saucer",
        value: $model.shortBreakDuration, range: 1...60, unit: "min"
      )
      SettingNumberField(
        label: "Long Break", icon: "moon",
        value: $model.longBreakDuration, range: 1...60, unit: "min"
      )
      SettingNumberField(
        label: "Long Break After", icon: "arrow.turn.down.right",
        value: $model.longBreakInterval, range: 1...10, unit: "×"
      )
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
  }

  private var toggleSection: some View {
    HStack(spacing: 10) {
      Image(systemName: "bell")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .frame(width: 14)

      Text("Notifications")
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)

      Toggle("Notifications", isOn: $model.notificationEnabled)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
        .onChange(of: model.notificationEnabled) { _, isOn in
          if isOn, notificationStatus == .notDetermined {
            Task { await requestNotificationPermission() }
          }
        }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
  }

  @ViewBuilder
  private var permissionButton: some View {
    if model.notificationEnabled, notificationStatus == .notDetermined || notificationStatus == .denied {
      Button {
        handlePermissionTap()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: notificationStatus == .denied ? "gear" : "bell.badge")
            .font(.system(size: 10))
          Text(notificationStatus == .denied ? "Open Settings" : "Enable Notifications")
            .font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .contentShape(Capsule())
      }
      .buttonStyle(.borderless)
      .glassEffect(.regular.interactive(), in: Capsule())
      .foregroundStyle(.primary)
      .accessibilityLabel(
        notificationStatus == .denied ? "Open notification settings" : "Enable notifications"
      )
    }
  }

  // MARK: - Helpers
  private func handlePermissionTap() {
    if notificationStatus == .denied {
      openNotificationSettings()
    } else {
      Task { await requestNotificationPermission() }
    }
  }

  private func openNotificationSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
  }

  private func requestNotificationPermission() async {
    guard notificationStatus == .notDetermined else { return }
    let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    notificationStatus = granted == true ? .authorized : .denied
  }

  private func checkNotificationPermission() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    notificationStatus = settings.authorizationStatus
  }
}

// MARK: - Number Field

/// Numeric settings field that tolerates transient input: filters to digits,
/// updates the binding live while values are in range, and clamps on commit.
private struct SettingNumberField: View {
  let label: String
  let icon: String
  @Binding var value: Int
  let range: ClosedRange<Int>
  let unit: String

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .frame(width: 14)

      Text(label)
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("", text: $text)
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .multilineTextAlignment(.trailing)
        .frame(width: 34)
        .textFieldStyle(.plain)
        .focused($isFocused)
        .onSubmit(commit)
        .onChange(of: isFocused) { _, focused in
          if !focused { commit() }
        }
        .onChange(of: text) { _, newValue in
          let filtered = String(newValue.filter(\.isNumber).prefix(3))
          if filtered != newValue { text = filtered }
          if let parsed = Int(filtered), range.contains(parsed) {
            value = parsed
          }
        }
        .onChange(of: value) { _, newValue in
          if !isFocused { text = String(newValue) }
        }
        .accessibilityLabel(label)

      Text(unit)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(width: 22, alignment: .leading)
    }
    .padding(.vertical, 3)
    .onAppear {
      text = String(value)
    }
  }

  private func commit() {
    if let parsed = Int(text) {
      value = min(max(parsed, range.lowerBound), range.upperBound)
    }
    text = String(value)
  }
}

/// Applies an optional keyboard shortcut, so buttons without one stay unmodified.
private struct KeyboardShortcutModifier: ViewModifier {
  let shortcut: KeyEquivalent?

  func body(content: Content) -> some View {
    if let shortcut {
      content.keyboardShortcut(shortcut, modifiers: [])
    } else {
      content
    }
  }
}

#Preview {
  MenuBarView(model: TimerModel())
}
