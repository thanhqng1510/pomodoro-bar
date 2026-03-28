import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let phase: Phase
    let timeText: String

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
                    Color(nsColor: .labelColor),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            VStack(spacing: 4) {
                Text(timeText)
                    .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(phase.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
        }
        .frame(width: 150, height: 150)
    }
}

#Preview {
    TimerRingView(
        progress: 0.45,
        phase: .focus,
        timeText: "13:42"
    )
    .padding(40)
}
