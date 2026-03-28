import SwiftUI

struct MenuBarView: View {
    var model: TimerModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(model: model, showSettings: $showSettings)
            } else {
                timerView
            }
        }
        .frame(width: 300)
    }

    private var timerView: some View {
        VStack(spacing: 14) {
            header
            timerRing
            phaseDots
            controlButtons
            footer
        }
        .padding(20)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: model.phase.icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(model.phase.rawValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var timerRing: some View {
        let mins = Int(model.timeRemaining) / 60
        let secs = Int(model.timeRemaining) % 60
        let text = String(format: "%d:%02d", mins, secs)

        return TimerRingView(
            progress: model.progress,
            phase: model.phase,
            timeText: text
        )
    }

    private var phaseDots: some View {
        HStack(spacing: 6) {
            ForEach(Phase.allCases) { p in
                let isActive = model.phase == p
                Circle()
                    .fill(isActive ? Color.primary : Color.clear)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var controlButtons: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.glass)
                .keyboardShortcut("r")

                Button {
                    model.toggle()
                } label: {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .frame(width: 40, height: 32)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    model.skip()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.glass)
                .keyboardShortcut("s")
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    MenuBarView(model: TimerModel())
}
