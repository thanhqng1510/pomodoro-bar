import Foundation
import AppKit
import UserNotifications

enum Phase: String, CaseIterable, Identifiable {
  case focus = "Focus"
  case shortBreak = "Short Break"
  case longBreak = "Long Break"

  var id: String { rawValue }
}

@MainActor
@Observable
final class TimerModel {
  // MARK: - Timer State
  var phase: Phase = .focus
  var isRunning = false
  var timeRemaining: TimeInterval = 0
  var totalTime: TimeInterval = 0
  var pomodorosInCycle = 0

  // MARK: - Settings (persisted to UserDefaults)
  var updater = Updater()

  var focusDuration: Int {
    didSet {
      defaults.set(focusDuration, forKey: Keys.focusDuration)
      if phase == .focus, !isRunning { resetToPhase(.focus) }
    }
  }
  var shortBreakDuration: Int {
    didSet {
      defaults.set(shortBreakDuration, forKey: Keys.shortBreakDuration)
      if phase == .shortBreak, !isRunning { resetToPhase(.shortBreak) }
    }
  }
  var longBreakDuration: Int {
    didSet {
      defaults.set(longBreakDuration, forKey: Keys.longBreakDuration)
      if phase == .longBreak, !isRunning { resetToPhase(.longBreak) }
    }
  }
  var longBreakInterval: Int {
    didSet { defaults.set(longBreakInterval, forKey: Keys.longBreakInterval) }
  }
  var notificationEnabled: Bool {
    didSet { defaults.set(notificationEnabled, forKey: Keys.notificationEnabled) }
  }

  // MARK: - Derived State
  var menuBarTitle: String {
    let mins = Int(timeRemaining) / 60
    let secs = Int(timeRemaining) % 60
    return String(format: "%d:%02d", mins, secs)
  }

  var progress: Double {
    guard totalTime > 0 else { return 0 }
    let totalSeconds = max(1, Int(totalTime))
    let elapsed = min(totalSeconds, max(0, totalSeconds - Int(timeRemaining)))
    return min(1, max(0, Double(elapsed) / Double(totalSeconds)))
  }

  var sessionLabel: String {
    switch phase {
    case .focus: "Focus \(pomodorosInCycle + 1)"
    case .shortBreak: "Short Break"
    case .longBreak: "Long Break"
    }
  }

  var completedInCycle: Int {
    phase == .longBreak ? longBreakInterval : pomodorosInCycle % longBreakInterval
  }

  var nextPhase: Phase {
    switch phase {
    case .focus:
      (pomodorosInCycle + 1) % longBreakInterval == 0 ? .longBreak : .shortBreak
    case .shortBreak, .longBreak:
      .focus
    }
  }

  var menuBarIcon: String {
    switch (phase, nextPhase) {
    case (.focus, .shortBreak): "brain.head.profile"
    case (.focus, .longBreak): "brain.head.profile"
    case (.shortBreak, .focus): "cup.and.saucer"
    case (.longBreak, .focus): "moon"
    case (_, _): "brain.head.profile"
    }
  }

  private var timerTask: Task<Void, Never>?
  private var phaseEndDate: Date?
  private let defaults = UserDefaults.standard

  private enum Keys {
    static let focusDuration = "focusDuration"
    static let shortBreakDuration = "shortBreakDuration"
    static let longBreakDuration = "longBreakDuration"
    static let longBreakInterval = "longBreakInterval"
    static let notificationEnabled = "notificationEnabled"
  }

  // MARK: - Init
  init() {
    focusDuration = Self.stored(defaults.integer(forKey: Keys.focusDuration), default: 25, in: 1...120)
    shortBreakDuration = Self.stored(defaults.integer(forKey: Keys.shortBreakDuration), default: 5, in: 1...60)
    longBreakDuration = Self.stored(defaults.integer(forKey: Keys.longBreakDuration), default: 15, in: 1...60)
    longBreakInterval = Self.stored(defaults.integer(forKey: Keys.longBreakInterval), default: 4, in: 1...10)
    notificationEnabled = defaults.object(forKey: Keys.notificationEnabled) as? Bool ?? true

    registerNotificationCategories()
    updater.checkForUpdates(force: true)  // verify on every launch so an update is never hidden by the daily throttle
    resetToPhase(.focus)
  }

  private static func stored(_ value: Int, default defaultValue: Int, in range: ClosedRange<Int>) -> Int {
    range.contains(value) ? value : defaultValue
  }

  // MARK: - Controls
  func start() {
    guard !isRunning else { return }
    isRunning = true
    let endDate = Date().addingTimeInterval(timeRemaining)
    phaseEndDate = endDate
    timerTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(250))
        guard let self, self.isRunning else { return }
        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
          self.timeRemaining = 0
          self.completePhase()
          return
        }
        self.timeRemaining = remaining
      }
    }
  }

  func pause() {
    guard isRunning else { return }
    if let endDate = phaseEndDate {
      timeRemaining = max(0, endDate.timeIntervalSinceNow)
    }
    isRunning = false
    phaseEndDate = nil
    timerTask?.cancel()
    timerTask = nil
  }

  func toggle() {
    isRunning ? pause() : start()
  }

  func reset() {
    pause()
    pomodorosInCycle = 0
    resetToPhase(.focus)
  }

  func skip() {
    pause()
    advancePhase()
  }

  // MARK: - Phase Management
  private func resetToPhase(_ p: Phase) {
    phase = p
    let duration: Int
    switch p {
    case .focus: duration = focusDuration
    case .shortBreak: duration = shortBreakDuration
    case .longBreak: duration = longBreakDuration
    }
    timeRemaining = TimeInterval(duration * 60)
    totalTime = timeRemaining
  }

  private func completePhase() {
    let completedPhase = phase
    pause()
    Task { await sendNotification(for: completedPhase) }
    advancePhase()
  }

  private func advancePhase() {
    switch phase {
    case .focus:
      pomodorosInCycle += 1
      if pomodorosInCycle >= longBreakInterval {
        pomodorosInCycle = 0
        resetToPhase(.longBreak)
      } else {
        resetToPhase(.shortBreak)
      }
    case .shortBreak, .longBreak:
      resetToPhase(.focus)
    }
  }

  // MARK: - Notifications
  private func registerNotificationCategories() {
    let startAction = UNNotificationAction(
      identifier: "START_ACTION",
      title: "Start Next",
      options: .foreground
    )
    let category = UNNotificationCategory(
      identifier: "PHASE_COMPLETE",
      actions: [startAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  private func sendNotification(for completedPhase: Phase) async {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()

    guard notificationEnabled else { return }

    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized else { return }

    let content = UNMutableNotificationContent()
    switch completedPhase {
    case .focus:
      content.title = "Focus Complete!"
      content.body = "Great work. Time for a break."
    case .shortBreak:
      content.title = "Break Over"
      content.body = "Ready to focus again?"
    case .longBreak:
      content.title = "Long Break Over"
      content.body = "Let's get back to work!"
    }
    content.sound = .default
    content.categoryIdentifier = "PHASE_COMPLETE"
    content.interruptionLevel = .timeSensitive
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    try? await center.add(request)
  }

  func handleNotificationAction() {
    start()
  }
}
