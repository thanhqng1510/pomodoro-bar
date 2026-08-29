import AppKit
import Observation
import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  var model: TimerModel?

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    return [.banner, .sound, .list]
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    let actionIdentifier = response.actionIdentifier
    if actionIdentifier == "START_ACTION" {
      if let model = model {
        Task { @MainActor in
          model.handleNotificationAction()
        }
      }
    } else {
      await MainActor.run {
        NSApp.activate()
      }
    }
  }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var model: TimerModel!
  private var statusItem: NSStatusItem!
  private let popover = NSPopover()
  private let notificationDelegate = NotificationDelegate()
  private var observationTask: Task<Void, Never>?

  func applicationDidFinishLaunching(_ notification: Notification) {
    model = TimerModel()
    UNUserNotificationCenter.current().delegate = notificationDelegate
    notificationDelegate.model = model

    setupStatusItem()
    setupPopover()
  }

  // MARK: - Status Item

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: 62)

    guard let button = statusItem.button else { return }

    updateStatusItem()

    button.target = self
    button.action = #selector(statusItemClicked(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])

    observeModel()
  }

  private func observeModel() {
    observationTask = Task { [weak self] in
      while !Task.isCancelled {
        await withCheckedContinuation { continuation in
          withObservationTracking {
            _ = self?.model.menuBarTitle
            _ = self?.model.menuBarIcon
            _ = self?.model.isRunning
          } onChange: {
            Task { @MainActor in
              self?.updateStatusItem()
              continuation.resume()
            }
          }
        }
      }
    }
  }

  private func updateStatusItem() {
    statusItem.button?.image = NSImage(systemSymbolName: model.menuBarIcon, accessibilityDescription: "Pomodoro Bar")
    statusItem.button?.imagePosition = .imageLeading
    statusItem.button?.title = model.menuBarTitle
    statusItem.button?.font = NSFont.menuBarFont(ofSize: 0)
  }

  // MARK: - Popover

  private func setupPopover() {
    popover.contentViewController = NSViewController()
    popover.contentViewController?.view = NSHostingView(rootView: MenuBarView(model: model))
    popover.behavior = .transient
    popover.animates = true
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }

    if event.type == .rightMouseUp {
      if popover.isShown { popover.close() }
      showContextMenu()
    } else {
      togglePopover()
    }
  }

  private func togglePopover() {
    if popover.isShown {
      popover.close()
    } else if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
    }
  }

  // MARK: - Context Menu

  private func showContextMenu() {
    let menu = NSMenu()
    menu.delegate = self

    let toggleItem = NSMenuItem(
      title: model.isRunning ? "Pause" : "Start",
      action: #selector(toggleTimer),
      keyEquivalent: ""
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quitItem)

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
  }

  @objc private func toggleTimer() {
    model.toggle()
  }

  func menuDidClose(_ menu: NSMenu) {
    statusItem.menu = nil
    menu.delegate = nil
  }
}
