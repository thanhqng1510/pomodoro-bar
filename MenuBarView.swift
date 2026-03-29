import SwiftUI
import UserNotifications
import AppKit

struct MenuBarView: View {
    var model: TimerModel
    @State private var showSettings = false
    @State private var notificationEnabled: Bool
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Namespace private var glassNamespace

    init(model: TimerModel) {
        self.model = model
        _notificationEnabled = State(initialValue: model.notificationEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 12) {
                header
            }
            contentView
        }
        .frame(width: 260, height: 280)
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
        }
        .buttonStyle(.borderless)
        .glassEffect(.regular.interactive(), in: Circle())
        .glassEffectID("left", in: glassNamespace)
    }

    @ViewBuilder
    private var exitButton: some View {
        if !showSettings {
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .glassEffect(.regular.interactive(), in: Circle())
            .glassEffectID("exit", in: glassNamespace)
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var contentView: some View {
        Group {
            if showSettings {
                settingsContent
            } else {
                mainContent
            }
        }
        .frame(height: 224)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 10) {
            TimerRingView(
                progress: model.progress,
                phase: model.phase,
                sessionLabel: model.sessionLabel,
                timeText: model.menuBarTitle
            )
            controlButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 8) {
            durationsSection
            toggleSection
            permissionButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 0) {
            controlButton(icon: "arrow.counterclockwise", action: model.reset)
            controlButton(icon: model.isRunning ? "pause.fill" : "play.fill", action: model.toggle, isPrimary: true)
            controlButton(icon: "forward.end.fill", action: model.skip)
        }
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func controlButton(icon: String, action: @escaping () -> Void, isPrimary: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 18 : 14))
                .frame(width: isPrimary ? 56 : 48, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Settings
    private var durationsSection: some View {
        VStack(spacing: 8) {
            durationRow(label: "Focus", icon: "circle.inset.filled", value: .focus)
            durationRow(label: "Short Break", icon: "cup.and.saucer", value: .shortBreak)
            durationRow(label: "Long Break", icon: "moon", value: .longBreak)
            durationRow(label: "Long Break After", icon: "arrow.turn.down.right", value: .interval)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func durationRow(label: String, icon: String, value: DurationValue) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: binding(for: value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 36)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var toggleSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text("Notification")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $notificationEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: notificationEnabled) { _, newValue in
                    model.notificationEnabled = newValue
                }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var permissionButton: some View {
        if notificationEnabled && (notificationStatus == .notDetermined || notificationStatus == .denied) {
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
        }
    }

    // MARK: - Helpers
    private enum DurationValue {
        case focus, shortBreak, longBreak, interval
    }

    private func binding(for value: DurationValue) -> Binding<String> {
        switch value {
        case .focus:
            Binding(
                get: { String(model.focusDuration) },
                set: { if let v = Int($0), v > 0 { model.focusDuration = min(v, 120) } }
            )
        case .shortBreak:
            Binding(
                get: { String(model.shortBreakDuration) },
                set: { if let v = Int($0), v > 0 { model.shortBreakDuration = min(v, 60) } }
            )
        case .longBreak:
            Binding(
                get: { String(model.longBreakDuration) },
                set: { if let v = Int($0), v > 0 { model.longBreakDuration = min(v, 60) } }
            )
        case .interval:
            Binding(
                get: { String(model.longBreakInterval) },
                set: { if let v = Int($0), v > 0 { model.longBreakInterval = min(v, 10) } }
            )
        }
    }

    private func handlePermissionTap() {
        if notificationStatus == .denied {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        } else {
            requestNotificationPermission()
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

#Preview {
    MenuBarView(model: TimerModel())
}
