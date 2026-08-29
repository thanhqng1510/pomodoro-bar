import SwiftUI

@main
struct PomodoroBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {}
  }
}

struct MenuBarLabel: View {
  var model: TimerModel

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: model.menuBarIcon)
        .padding(.trailing, 4)
      Text(model.menuBarTitle)
        .monospacedDigit()
    }
  }
}
