import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let phase: Phase
    let sessionLabel: String
    let timeText: String

    private var ringColor: Color {
        switch phase {
        case .focus:
            return Color(red: 1.0, green: 0.6, blue: 0.5)
        case .shortBreak, .longBreak:
            return Color(red: 0.5, green: 0.85, blue: 0.6)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(nsColor: .quaternaryLabelColor),
                    lineWidth: 2
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: progress)

            VStack(spacing: 4) {
                Text(timeText)
                    .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: timeText)

                Text(sessionLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 150, height: 150)
    }
}

#Preview {
    TimerRingView(
        progress: 0.45,
        phase: .focus,
        sessionLabel: "Focus 1",
        timeText: "13:42"
    )
    .padding(40)
}
