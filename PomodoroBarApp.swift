import SwiftUI
import UserNotifications
import AppKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var model: TimerModel?
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        if actionIdentifier == "START_ACTION" {
            if let model = model {
                Task { @MainActor in
                    model.handleNotificationAction()
                }
            }
        } else {
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@main
struct PomodoroBarApp: App {
    @State private var model = TimerModel()
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
                .onAppear {
                    notificationDelegate.model = model
                }
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
            HStack(spacing: 4) {
                Image(systemName: model.phase.icon)
                    .padding(.trailing, 4)
                Text(model.menuBarTitle)
            }
        } else {
            Image(systemName: "circle.dotted")
        }
    }
}
