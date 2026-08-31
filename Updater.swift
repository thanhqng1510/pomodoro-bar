import Foundation
import AppKit
import Darwin

/// In-app updater for Pomodoro Bar. Checks the GitHub Releases API for a newer
/// build, exposes it through observable state, and applies an update by writing
/// the release archive to a temp dir and handing the swap to a detached helper
/// (update.sh, launched via posix_spawn so it survives this app quitting). The
/// helper verifies the SHA-256, replaces /Applications/PomodoroBar.app, and
/// relaunches.
///
/// Distribution stays on the curl installer (install.sh); this only upgrades an
/// already-installed copy. If the app was installed via a Homebrew cask, the
/// Caskroom receipt would desync if we swapped /Applications ourselves, so we
/// redirect the user to `brew upgrade` instead of self-replacing.
@MainActor
@Observable
final class Updater {
  private static let repo = "thanhqng1510/pomodoro-bar"
  private static let appName = "PomodoroBar"

  private static var latestURL: String {
    "https://api.github.com/repos/\(Self.repo)/releases/latest"
  }

  /// User-facing update state, surfaced straight to the Settings UI.
  enum State {
    case idle
    case checking
    case available
    case upToDate
    case downloading
    case updating
    case error
  }

  var state: State = .idle
  var latestVersion: String = ""
  var currentVersion: String
  var progress: Double = 0
  var error: String = ""

  var isHomebrew: Bool {
    let fm = FileManager.default
    let paths = ["/opt/homebrew/Caskroom/pomodoro-bar", ("~/Caskroom/pomodoro-bar" as NSString).expandingTildeInPath]
    return paths.contains { fm.fileExists(atPath: $0) }
  }

  private var defaults = UserDefaults.standard

  private enum Keys {
    static let lastCheck = "lastUpdateCheckDate"
  }

  init() {
    // AppVersion.current is stamped from the release tag by set-version.sh.
    currentVersion = AppVersion.current
  }

  // MARK: - Checking

  /// Checks for a newer release. `force` bypasses the once-per-day cache (used
  /// by the "Check for Updates…" control); otherwise a launch-time check is
  /// throttled so we never hammer GitHub's unauthenticated API.
  func checkForUpdates(force: Bool = false) {
    guard state != .checking else { return }
    guard force || isCheckDue() else { return }

    state = .checking
    error = ""
    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let session = Foundation.URLSession.shared
        guard let url = URL(string: Self.latestURL) else {
          return self.fail("Invalid update URL.")
        }
        let (data, _) = try await session.data(from: url)
        guard let body = String(data: data, encoding: .utf8) else {
          return self.fail("Could not read response from GitHub.")
        }
        let remote = self.latestTag(in: body)
        guard let remote else { return self.fail("No published release was found on GitHub.") }
        self.rememberCheck()
        if Self.compareVersions(remote, self.currentVersion) > 0 {
          self.latestVersion = remote
          self.state = .available
        } else {
          self.state = .upToDate
        }
      } catch {
        self.fail("Could not reach GitHub. Check your connection and try again.")
      }
    }
  }

  private func fail(_ message: String) {
    state = .idle
    error = message
  }

  private func rememberCheck() {
    defaults.set(Date(), forKey: Keys.lastCheck)
  }

  private func isCheckDue() -> Bool {
    if let last = defaults.object(forKey: Keys.lastCheck) as? Date {
      Date().timeIntervalSince(last) >= TimeInterval(24 * 60 * 60)
    } else {
      true
    }
  }

  // MARK: - Release parsing

  /// Pulls "tag_name" (strips the leading "v") from the releases/latest JSON.
  /// Mirrors install.sh's string-scanning so we don't depend on a JSON decoder.
  private func latestTag(in body: String) -> String? {
    guard let keyRange = body.range(of: "\"tag_name\"") else { return nil }
    let suffix = String(body[keyRange.upperBound...])
    guard let colon = suffix.range(of: ":") else { return nil }
    let afterColon = String(suffix[colon.upperBound...])
    guard let open = afterColon.range(of: "\"") else { return nil }
    let inner = afterColon[open.upperBound...]
    guard let close = inner.range(of: "\"") else { return nil }
    let raw = String(inner[inner.startIndex..<close.lowerBound])
    guard raw.hasPrefix("v") else { return nil }
    return String(raw.dropFirst(1))
  }

  private static func compareVersions(_ a: String, _ b: String) -> Int {
    let ap = a.split(separator: ".").map { Int($0) ?? 0 }
    let bp = b.split(separator: ".").map { Int($0) ?? 0 }
    let n = max(ap.count, bp.count)
    for i in 0..<n {
      let x = i < ap.count ? ap[i] : 0
      let y = i < bp.count ? bp[i] : 0
      if x != y { return x > y ? 1 : -1 }
    }
    return 0
  }

  // MARK: - Applying

  /// Downloads the new release zip and sidecar manifests, then detaches the
  /// update helper and quits. The running bundle can't be replaced in place, so
  /// update.sh does the swap + checksum + relaunch after we exit.
  func applyUpdate() {
    guard state == .available else { return }
    if isHomebrew {
      // If installed via Homebrew cask, guide the user to brew upgrade
      error = "Run 'brew upgrade pomodoro-bar' in terminal to update."
      return
    }
    state = .downloading
    progress = 0
    error = ""
    let version = latestVersion
    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let base = "https://github.com/\(Self.repo)/releases/download/v\(version)"
        let session = Foundation.URLSession.shared
        let work = Foundation.FileManager.default.temporaryDirectory
          .appending(component: "PomodoroBar-update-\(version)")
        _ = try? Foundation.FileManager.default.createDirectory(
          at: work, withIntermediateDirectories: true)
        let zipURL = URL(string: "\(base)/\(Self.appName)-\(version).zip")
        let cksURL = URL(string: "\(base)/checksums.txt")
        guard zipURL != nil else { return self.fail("Bad release download URL.") }
        guard cksURL != nil else { return self.fail("Bad release download URL.") }

        // Stream the zip so we can report real progress on the Download button.
        let (zipBytes, zipResponse) = try await session.bytes(from: zipURL!)
        let total = Double(zipResponse.expectedContentLength)
        var zipData = Data()
        if total > 0 {
          zipData.reserveCapacity(Int(total))
        }
        var lastReportedCount = 0
        for try await byte in zipBytes {
          zipData.append(byte)
          if total > 0, zipData.count - lastReportedCount >= 65536 {
            lastReportedCount = zipData.count
            self.progress = min(1, Double(zipData.count) / total)
          }
        }
        self.progress = 1
        let (cksData, _) = try await session.data(from: cksURL!)
        let cks = String(data: cksData, encoding: .utf8) ?? ""

        let zipFile = work.appending(component: "\(Self.appName)-\(version).zip")
        let cksFile = work.appending(component: "checksums.txt")
        try zipData.write(to: zipFile)
        try cks.write(to: cksFile, atomically: false, encoding: .utf8)

        // Version manifest for the helper, then detach it.
        let manifest = work.appending(component: "update.manifest")
        try "version=\(version)\n".write(to: manifest, atomically: false, encoding: .utf8)
        let helper = work.appending(component: "update.sh")
        if let scriptURL = Bundle.main.url(forResource: "update.sh", withExtension: nil) {
          let script = (try? String(data: Data(contentsOf: scriptURL), encoding: .utf8)) ?? ""
          try script.write(to: helper, atomically: false, encoding: .utf8)
        }
        // posix_spawn needs an executable file.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        self.launchDetached(script: helper)
        self.state = .updating
        // The helper waits for this process to exit before swapping. Quit now
        // so /Applications can be replaced without racing the running bundle.
        NSApp.terminate(nil)
      } catch {
        self.fail("Download failed. Nothing was changed.")
      }
    }
  }

  /// Launches `script` in its own session so it survives this app quitting —
  /// that's what lets it swap /Applications/PomodoroBar.app while we're gone.
  /// Uses posix_spawn (verified in probes) rather than NSWorkspace.open, which
  /// bundles the child with our lifecycle.
  private func launchDetached(script URL: URL) {
    var pid: pid_t = 0
    var attr: posix_spawnattr_t?
    posix_spawnattr_init(&attr)
    posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
    defer { posix_spawnattr_destroy(&attr) }

    let path = URL.path
    let cArgs: [UnsafeMutablePointer<CChar>?] = [strdup(path), nil]
    let rc = posix_spawn(&pid, path, nil, &attr, cArgs, nil)
    cArgs.forEach { free($0) }
    if rc != 0 {
      fail("Could not start the update helper (errno \(rc)).")
    }
  }
}