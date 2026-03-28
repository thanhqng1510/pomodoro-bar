import SwiftUI

struct SettingsView: View {
    var model: TimerModel
    @Binding var showSettings: Bool

    @State private var focusMinutes: Int
    @State private var shortBreakMinutes: Int
    @State private var longBreakMinutes: Int
    @State private var longBreakInterval: Int
    @State private var soundEnabled: Bool
    @State private var notificationEnabled: Bool

    init(model: TimerModel, showSettings: Binding<Bool>) {
        self.model = model
        self._showSettings = showSettings
        _focusMinutes = State(initialValue: model.focusDuration)
        _shortBreakMinutes = State(initialValue: model.shortBreakDuration)
        _longBreakMinutes = State(initialValue: model.longBreakDuration)
        _longBreakInterval = State(initialValue: model.longBreakInterval)
        _soundEnabled = State(initialValue: model.soundEnabled)
        _notificationEnabled = State(initialValue: model.notificationEnabled)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            durations
            toggles
        }
        .padding(20)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                applyChanges()
                showSettings = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var durations: some View {
        VStack(spacing: 12) {
            durationRow(label: "Focus", icon: "circle.inset.filled", value: $focusMinutes, range: 1...120, unit: "min")
            durationRow(label: "Short Break", icon: "cup.and.saucer", value: $shortBreakMinutes, range: 1...60, unit: "min")
            durationRow(label: "Long Break", icon: "moon", value: $longBreakMinutes, range: 1...60, unit: "min")
            durationRow(label: "Long Break After", icon: "arrow.turn.down.right", value: $longBreakInterval, range: 1...10, unit: "sessions")
        }
    }

    private func durationRow(label: String, icon: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 1) {
                    Button {
                        if value.wrappedValue > range.lowerBound {
                            value.wrappedValue -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 28, height: 26)
                    }
                    .buttonStyle(.glass)

                    Text("\(value.wrappedValue)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(width: 36)

                    Button {
                        if value.wrappedValue < range.upperBound {
                            value.wrappedValue += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 28, height: 26)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var toggles: some View {
        VStack(spacing: 12) {
            toggleRow(label: "Sound", icon: "speaker.wave.2", isOn: $soundEnabled)
            toggleRow(label: "Notification", icon: "bell", isOn: $notificationEnabled)
        }
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

    private func applyChanges() {
        model.focusDuration = focusMinutes
        model.shortBreakDuration = shortBreakMinutes
        model.longBreakDuration = longBreakMinutes
        model.longBreakInterval = longBreakInterval
        model.soundEnabled = soundEnabled
        model.notificationEnabled = notificationEnabled
        model.reset()
    }
}
