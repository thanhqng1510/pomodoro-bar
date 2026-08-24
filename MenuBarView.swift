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
      checkNotificationPermission()
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
    .accessibilityLabel(showSettings ? "Back to timer" : "Settings")
    .help(showSettings ? "Back to timer" : "Settings")
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
        isPaused: model.isPaused
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
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
          .font(.system(size: 13))
        VStack(alignment: .leading, spacing: 2) {
          Text(bannerTitle)
            .font(.system(size: 11.5, weight: .bold))
          if !model.updater.error.isEmpty {
            Text(model.updater.error)
              .font(.system(size: 10))
              .foregroundStyle(.red)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button {
          model.updater.applyUpdate()
        } label: {
          updateButtonLabel
        }
        .buttonStyle(.borderless)
        .glassEffect(.regular.interactive(), in: Capsule())
        .controlSize(.small)
        .disabled(model.updater.state == .downloading || model.updater.state == .updating)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 10)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    case .checking:
      HStack(spacing: 8) {
        Image(systemName: "stethoscope")  // placeholder while thinking
          .font(.system(size: 10))
        Text("Checking for updates…")
          .font(.system(size: 11))
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 10)
      .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    case .upToDate:
      rowStatus("Up to date (v\(model.updater.currentVersion)).", "checkmark.circle")
    case .idle, .error:
      if !model.updater.error.isEmpty {
        rowStatus(model.updater.error, "exclamationmark.triangle")
      }
    }
  }

  private var bannerTitle: String {
    switch model.updater.state {
    case .downloading:
      "Downloading v\(model.updater.latestVersion)… \(Int(model.updater.progress * 100))%"
    case .updating:
      "Installing v\(model.updater.latestVersion)…"
    default:
      "New version v\(model.updater.latestVersion) available."
    }
  }

  @ViewBuilder
  private var updateButtonLabel: some View {
    let u = model.updater
    if u.state == .downloading {
      HStack(spacing: 4) {
        ProgressView(value: u.progress)
          .controlSize(.small)
          .frame(width: 16, height: 16)
        Text("\(Int(u.progress * 100))%")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
      }
    } else if u.state == .updating {
      ProgressView()
        .controlSize(.small)
        .frame(width: 16, height: 16)
    } else {
      Text("Download")
        .font(.system(size: 11, weight: .medium))
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
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        model.updater.checkForUpdates(force: true)
      } label: {
        Text("Check again")
          .font(.system(size: 11, weight: .medium))
      }
      .buttonStyle(.borderless)
      .glassEffect(.regular.interactive(), in: Capsule())
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
        label: "Focus", icon: "circle.inset.filled",
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
            requestNotificationPermission()
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
      requestNotificationPermission()
    }
  }

  private func openNotificationSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
      NSWorkspace.shared.open(url)
    }
  }

  private func requestNotificationPermission() {
    guard notificationStatus == .notDetermined else { return }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async {
        notificationStatus = granted ? .authorized : .denied
      }
    }
  }

  private func checkNotificationPermission() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let status = settings.authorizationStatus
      DispatchQueue.main.async {
        notificationStatus = status
      }
    }
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
