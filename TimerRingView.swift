import SwiftUI

extension Phase {
  var color: Color {
    switch self {
    case .focus: Color("PhaseFocus")
    case .shortBreak: Color("PhaseShortBreak")
    case .longBreak: Color("PhaseLongBreak")
    }
  }
}

struct TimerRingView: View {
  let progress: Double
  let phase: Phase
  let sessionLabel: String
  let timeText: String
  var isPaused = false

  var body: some View {
    ZStack {
      Circle()
        .stroke(.quaternary, lineWidth: 3)

      Circle()
        .trim(from: 0, to: max(progress, 0.005))
        .stroke(
          phase.color.gradient,
          style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

      VStack(spacing: 4) {
        Text(timeText)
          .font(.system(size: 36, weight: .light, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
          .animation(.easeInOut(duration: 0.25), value: timeText)

        Text(isPaused ? "Paused" : sessionLabel)
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
          .tracking(0.8)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .frame(width: 150, height: 150)
    .opacity(isPaused ? 0.6 : 1)
    .animation(.easeInOut(duration: 0.2), value: isPaused)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(phase.rawValue) timer")
    .accessibilityValue(isPaused ? "Paused at \(timeText)" : "\(timeText) remaining")
  }
}

struct CycleDotsView: View {
  let completed: Int
  let total: Int
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<max(total, 1), id: \.self) { index in
        if index < completed {
          Circle().fill(color)
        } else {
          Circle().fill(.quaternary)
        }
      }
    }
    .frame(height: 6)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Cycle progress")
    .accessibilityValue("\(completed) of \(total) pomodoros completed")
  }
}

#Preview {
  VStack(spacing: 20) {
    TimerRingView(
      progress: 0.45,
      phase: .focus,
      sessionLabel: "Focus 1",
      timeText: "13:42"
    )
    CycleDotsView(completed: 2, total: 4, color: Phase.focus.color)
  }
  .padding(40)
}
