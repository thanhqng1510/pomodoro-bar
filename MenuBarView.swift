import SwiftUI

struct MenuBarView: View {
    var model: TimerModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            contentView
        }
        .frame(width: 260, height: 280)
    }

    private var header: some View {
        HStack {
            if showSettings {
                Button { showSettings = false } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            } else {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !showSettings {
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var contentView: some View {
        if showSettings {
            SettingsContent(model: model, showSettings: $showSettings)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        } else {
            VStack(spacing: 10) {
                timerRing
                controlButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var timerRing: some View {
        TimerRingView(
            progress: model.progress,
            phase: model.phase,
            sessionLabel: model.sessionLabel,
            timeText: model.menuBarTitle
        )
    }

    private var controlButtons: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 2) {
                Button { model.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .frame(width: 48, height: 40)
                }
                .buttonStyle(.plain)

                Button { model.toggle() } label: {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .frame(width: 56, height: 40)
                }
                .buttonStyle(.plain)

                Button { model.skip() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                        .frame(width: 48, height: 40)
                }
                .buttonStyle(.plain)
            }
            .background(.thinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
    }
}

#Preview {
    MenuBarView(model: TimerModel())
}
