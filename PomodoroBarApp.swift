import SwiftUI

@main
struct PomodoroBarApp: App {
    @State private var model = TimerModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    var model: TimerModel

    var body: some View {
        if model.isRunning || model.timeRemaining != model.totalTime {
            Text(model.menuBarTitle)
        } else {
            Image(systemName: "circle.dotted")
        }
    }
}
