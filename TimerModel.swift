import Foundation
import AppKit
@preconcurrency import UserNotifications
import AVFoundation

enum Phase: String, CaseIterable, Identifiable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .focus: "circle.inset.filled"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "moon"
        }
    }
}

@MainActor
@Observable
final class TimerModel {
    // MARK: - Timer State
    var phase: Phase = .focus
    var isRunning = false
    var timeRemaining: TimeInterval = 0
    var totalTime: TimeInterval = 0
    var completedPomodoros = 0

    // MARK: - Settings
    var focusDuration: Int = 25 {
        didSet { if phase == .focus, !isRunning { resetToCurrentPhase() } }
    }
    var shortBreakDuration: Int = 5 {
        didSet { if phase == .shortBreak, !isRunning { resetToCurrentPhase() } }
    }
    var longBreakDuration: Int = 15 {
        didSet { if phase == .longBreak, !isRunning { resetToCurrentPhase() } }
    }
    var longBreakInterval: Int = 4
    var soundEnabled = true
    var notificationEnabled = true

    // MARK: - Menu bar title
    var menuBarTitle: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalTime)
    }

    private var timerTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Init
    init() {
        resetToPhase(.focus)
    }

    // MARK: - Controls
    func start() {
        guard !isRunning else { return }
        isRunning = true
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                guard self.isRunning else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.completePhase()
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset() {
        pause()
        completedPomodoros = 0
        resetToPhase(.focus)
    }

    func skip() {
        pause()
        advancePhase()
    }

    // MARK: - Phase Management
    private func resetToCurrentPhase() {
        resetToPhase(phase)
    }

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
        pause()
        playSound()
        sendNotification()
        advancePhase()
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            completedPomodoros += 1
            if completedPomodoros % longBreakInterval == 0 {
                resetToPhase(.longBreak)
            } else {
                resetToPhase(.shortBreak)
            }
        case .shortBreak, .longBreak:
            resetToPhase(.focus)
        }
    }

    // MARK: - Sound
    private func playSound() {
        guard soundEnabled else { return }
        if let url = Bundle.main.url(forResource: "chime", withExtension: "wav") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Notifications
    private func sendNotification() {
        guard notificationEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [phase = self.phase] granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            switch phase {
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
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

