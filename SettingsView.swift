import SwiftUI
import UserNotifications
import AppKit

struct SettingsContent: View {
    var model: TimerModel
    @Binding var showSettings: Bool

    @State private var focusMinutes: String
    @State private var shortBreakMinutes: String
    @State private var longBreakMinutes: String
    @State private var longBreakInterval: String
    @State private var notificationEnabled: Bool
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    init(model: TimerModel, showSettings: Binding<Bool>) {
        self.model = model
        self._showSettings = showSettings
        _focusMinutes = State(initialValue: String(model.focusDuration))
        _shortBreakMinutes = State(initialValue: String(model.shortBreakDuration))
        _longBreakMinutes = State(initialValue: String(model.longBreakDuration))
        _longBreakInterval = State(initialValue: String(model.longBreakInterval))
        _notificationEnabled = State(initialValue: model.notificationEnabled)
    }

    var body: some View {
        VStack(spacing: 10) {
            durations
            toggles
            permissionButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear {
            checkNotificationPermission()
        }
        .onDisappear {
            applyChanges()
        }
    }

    private var durations: some View {
        VStack(spacing: 8) {
            durationRow(label: "Focus", icon: "circle.inset.filled", value: $focusMinutes, range: 1...120)
            durationRow(label: "Short Break", icon: "cup.and.saucer", value: $shortBreakMinutes, range: 1...60)
            durationRow(label: "Long Break", icon: "moon", value: $longBreakMinutes, range: 1...60)
            durationRow(label: "Long Break After", icon: "arrow.turn.down.right", value: $longBreakInterval, range: 1...10)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func durationRow(label: String, icon: String, value: Binding<String>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 36)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: value.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        value.wrappedValue = filtered
                    }
                    if let int = Int(filtered), !range.contains(int) {
                        value.wrappedValue = String(min(max(int, range.lowerBound), range.upperBound))
                    }
                }
        }
    }

    private var toggles: some View {
        VStack(spacing: 8) {
            toggleRow(label: "Notification", icon: "bell", isOn: $notificationEnabled)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func toggleRow(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var permissionButton: some View {
        Group {
            if notificationEnabled && (notificationStatus == .notDetermined || notificationStatus == .denied) {
                Button {
                    if notificationStatus == .denied {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    } else if notificationStatus == .notDetermined {
                        requestNotificationPermissionWithTest()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: notificationStatus == .denied ? "gear" : "bell.badge")
                            .font(.system(size: 10))
                        Text(notificationStatus == .denied ? "Open Settings" : "Enable Notifications")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
    }

    private func requestNotificationPermissionWithTest() {
        guard notificationStatus == .notDetermined else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationStatus = granted ? .authorized : .denied
                if granted {
                    sendTestNotification()
                }
            }
        }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Notifications are working!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                notificationStatus = status
            }
        }
    }

    private func applyChanges() {
        var changed = false
        if let v = Int(focusMinutes), 1...120 ~= v, v != model.focusDuration {
            model.focusDuration = v
            changed = true
        }
        if let v = Int(shortBreakMinutes), 1...60 ~= v, v != model.shortBreakDuration {
            model.shortBreakDuration = v
            changed = true
        }
        if let v = Int(longBreakMinutes), 1...60 ~= v, v != model.longBreakDuration {
            model.longBreakDuration = v
            changed = true
        }
        if let v = Int(longBreakInterval), 1...10 ~= v, v != model.longBreakInterval {
            model.longBreakInterval = v
            changed = true
        }
        if notificationEnabled != model.notificationEnabled {
            model.notificationEnabled = notificationEnabled
            changed = true
        }
        if changed {
            model.reset()
        }
    }
}
