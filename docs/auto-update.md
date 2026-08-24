# Auto-update for Pomodoro Bar

Research notes, grounded in primary sources (official docs, framework source, first-party Apple docs, app repos). Dense and engineer-facing. All claims are cited inline; where a claim could not be verified from a primary source it is called out explicitly.

---

## TL;DR

- The dominant, actively-maintained option for direct-distribution (non-App-Store) macOS auto-update is **Sparkle 2.x** (repo single-version, current release **2.9.6**, published 2026-08-17). Nothing else is remotely as maintained for this use case.
- **Custom updater** (app calls `GET /repos/{owner}/{repo}/releases/latest`, downloads a zip/dmg, verifies a signature, replaces itself, relaunches) is the realistic second option, and is what several menu-bar apps actually do (verified in **Stats** source). Pomodoro Bar's existing `install.sh` is essentially a manual version of this already.
- **The problem to solve is not the download — it is that a running app at `/Applications` cannot be overwritten in place.** Both Sparkle and Stats solve this with a staged swap: copy new bundle to a staging dir, move the running old bundle aside, atomically move the new bundle in, then relaunch from the new path. In Sparkle this is architected as a privileged `Autoupdate` installer submitted to `launchd`; in Stats it is a detached `updater.sh` (optionally run via deprecated `AuthorizationExecuteWithPrivileges` to gain root).
- **Integrity/security:** GitHub Releases are served strictly over HTTPS via a 302 to a signed `release-assets.githubusercontent.com` URL. A naive updater that *only* trusts HTTPS is still a DNS/MITM surface; the robust defense is to verify a **cryptographic signature independent of the transport**. Pomodoro Bar already publishes a **SHA-256 `checksums.txt`** alongside each release zip — that is sufficient integrity for an unsigned build if you actually verify it.
- **Code-signing/notarization:** Sparkle does **not** require the host app to be Developer ID signed, nor does it require updates to be signed — but its *recommended* configuration is HTTPS + EdDSA-signed archive + Developer ID code-signed/notarized app. For an ad-hoc-signed (no Team ID), non-notarized app like Pomodoro Bar today, Sparkle still works and validates integrity via the EdDSA signature of the update archive. Stats demonstrates a fully working custom updater that validates the **new** app is code-signed by the same Team ID.
- **Apple-side (Gatekeeper):** Apps installed by an updater that replaced a file under `/Applications` can be re-scanned/translocated. Sparkle mitigates by clearing quarantine and running a `gktool scan` on the new bundle before relaunch. For an unsigned/non-notarized app the OS will still show the "unidentified developer" Gatekeeper prompt unless the team ID is Developer ID signed + notarized; the update itself cannot make that go away.
- **macOS 26 / 2025-26:** Sparkle added explicit **macOS Tahoe support** (2.8.0 UI modernization + Tahoe); macOS 26 bumped the default minimum TLS to 1.2 for `URLSession`/`NSURLSession` (matters for your updater's HTTP stack — use a TLS 1.2+ provider). No primary Apple source was found for a Gatekeeper-specific auto-update change in Tahoe; treat that as unverified.

**Bottom line for Pomodoro Bar:** Sparkle gives you a secure, battle-tested, low-code path but requires an EdDSA keypair + appcast hosting (which your GitHub Releases already does for archive uniqueness) and introduces `Sparkle.framework` into a SwiftUI menu-bar app — and its EdDSA-signed-archive model does NOT strictly require your app to be signed. A custom updater is a thin, fully in-repo implementation mirroring your existing `install.sh` (GitHub API + SHA-256) plus the one tricky piece: a detached `launchd`-style helper or `smjuser`/`open` relaunch for replacing the running app. Recommendation is in the final section.

---

## 1. Ecosystem of options

### (a) Sparkle (2.x) — recommended for direct distribution
Primary source: the repo itself and its GitHub-hosted docs.

- "Secure and reliable software update framework for macOS." Sparkle 2 adds support for application sandboxing, custom UIs, updating external bundles, and a more modern architecture (source: https://github.com/sparkle-project/Sparkle — README.markdown).
- Updates "verified using EdDSA signatures and Apple Code Signing", supports "delta updates", "atomic-safe installs", background auto-download/install, channels (beta), phased rollouts, critical/major markers (source: same README).
- "Uses RSS-based appcasts for release information... a de-facto standard" (same README).
- Requirements: Runtime macOS 12.0+ on 2.x (your target macOS 26 satisfies this); build requires latest major Xcode (and one version less); **HTTPS** to serve updates (source: README).
- Maintenance: actively maintained. Latest release **2.9.6** (2026-08-17) and a steady release cadence through 2.9.5/2.9.4 (June/July 2026) (source: https://api.github.com/repos/sparkle-project/Sparkle/releases ; current tag `2.9.6`, published 2026-08-17).
- Designed for: lock-in-free, self-hostable or GitHub-served update framework. In use by OBS Studio, VLC Media Player, Oracle Java, SourceTree, Wireshark, XQuartz and "many more" (source: https://sparkle-project.org/about/).

### (b) Custom updater (fetch GitHub Releases API + self-replace)
- Not a "framework" — you write it. Proven live in **Stats** (see §5). Matches Pomodoro's existing distribution model closely.
- Maintained by you; nothing external to vet (but you own all security edges).
- Designed for: apps already distributed via GitHub Releases + curl installer, want minimal dependencies, and are comfortable owning the update pipeline.

### (c) Anything else worth knowing
- **Squirrel / Squirrel.Mac** (Electron's updater): fork of Sparkle that powers Electron apps (used to be in Slack/VS Code family). It is an "OS X framework focused on making application updates as safe and transparent as updates to a website" — server-driven (the server decides which update; "updates to the version the server tells it"), cross-platform via a `ShipIt` launcher. macOS-side maintenance is essentially on-hold (tag 0.3.2 published 2017); its last tagged macOS release is 0.3.2 (source: https://github.com/Squirrel/Squirrel.Mac — README, and repo releases list via https://api.github.com/repos/Squirrel/Squirrel.Mac/releases). The Windows sibling (`Squirrel.Windows`) is actively "seeking maintainers" (source: the linked repo README). => Not recommended as an alternative to Sparkle unless you're already in the Electron world.
- **Mac system mechanisms:** there is no first-party Apple "auto-update system service" exposed for third-party apps. App Store apps update via StoreKit/Auto Update mechanics, but Pomodoro is not App Store-distributed, so that path is a non-starter. macOS **does** relaunch apps and respect LSSharedFileList/`NSWorkspace` for launching, but there's no framework-level updater API — which is exactly the gap Sparkle occupies.
- **vendor-built** update systems (e.g., Notion's custom, or Microsoft's WU-based one) are private; not reusable.

---

## 2. Sparkle deep dive

Primary source: repo at `https://github.com/sparkle-project/Sparkle` (branch `2.x`) and rendered docs at `https://sparkle-project.org/documentation/`.

### End-to-end flow
1. **Appcast feed.** Sparkle reads an RSS feed (appcast) specified by a `SUFeedURL` key in the app's `Info.plist`. Each `<item>` is a release candidate with `sparkle:version` (required), `sparkle:shortVersionString`, `sparkle:releaseNotesLink`, `sparkle:minimumSystemVersion`, `sparkle:minimumAutoupdateVersion` (major-upgrade gating), and an `<enclosure url=... sparkle:edSignature=... length=..."` pointing at the downloadable archive. (source: https://sparkle-project.org/documentation/publishing/ and `Resources/SampleAppcast.xml`).
2. **Version comparison.** Sparkle compares the app's `CFBundleVersion` (Info.plist) against `sparkle:version`. You must keep `CFBundleVersion` incrementing; a human-readable `CFBundleShortVersionString` can hide internal versions from the UI (source: docs/publishing — `sparkle:version`, `sparkle:shortVersionString` semantics). For arm64-only apps, use `sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>` (added in Sparkle 2.9, source: CHANGELOG + docs/publishing).
3. **EdDSA signatures.** Updates are signed with an EdDSA (ed25519) keypair. The **private** key is stored in the developer's macOS Keychain; the **public** key is embedded in the app as `SUPublicEDKey` in `Info.plist`. Tooling: `generate_keys` (create pair, store in Keychain) and `sign_update` (EdDSA-sign an archive, or embed a signature into an appcast/release note). `generate_appcast` automates appcast + signature + delta generation (source: docs/signing `#signing-keys`; source `generate_keys/main.swift`, `sign_update/main.swift`; README "Generate the appcast" section). Archive types supported: dmg, zip, tar, Apple Archive, install/pkg.
4. **Updater controller.** `SPUStandardUpdaterController` is the Cocoa go-to: drag it in/subclass it; it "checks for updates automatically, and manages the update UI" with no further API required. In Sparkle 2, `SUUpdater` is deprecated in favor of `SPUStandardUpdaterController` (source: docs — step 2 "Set up a Sparkle updater object").
5. **Download + validation.** The updater downloads the archive (over HTTPS), extracts, and the **installer (`Autoupdate`) does extraction, cryptographic validation, and installation all in one process** (privilege separation). It moves the download into its own directory, rejects symbolic-link attacks, validates the archive's EdDSA signature (and, if the bundle has one, the code signature), refuses downgrades, then installs (source: `Documentation/Installation.md`, `Documentation/Security.md`).
6. **Apply update (relaunch/installer).** For regular app updates, Sparkle **terminates the running app** (sends an Apple quit event), then performs the file swap in three stages. When the update's code signature matches the installed copy, it does an **atomic swap** and runs a **Gatekeeper scan** (`/usr/bin/gktool scan <app>`, macOS 14.4+) to pre-warm launch and avoid "Verifying..." dialog. If it cannot safely do the atomic swap, it falls back to the legacy path (source: `Autoupdate/SUPlainInstaller.m`). Elevated installs (root) submit the installer as a one-time `launchd` agent/daemon (via `SMJob`/privilege separation), which is what permits replacing apps in `/Applications` requiring admin (source: `Documentation/Installation.md`, `Documentation/Security.md`). Reopening is handled by the progress agent/`Updater.app`.

### Sandboxing / XPC
- XPC Services (`Installer.xpc` for installs, `Downloader.xpc` for network) are bundled inside `Sparkle.framework`. **The Installer XPC Service (`SUEnableInstallerLauncherService`) is required only for sandboxed apps** to install outside the sandbox. Sandboxed apps also need a Mach-lookup temporary exception entitlement. **If your app is not sandboxed, you don't need these** (source: https://sparkle-project.org/documentation/sandboxing/). Sparkle runs fine unsandboxed, which is exactly Pomodoro's state.

### Must updates be code-signed? Must the app be notarized?
- **No — but it strongly changes what validation protects against.** Sparkle's docs recommend (not require): "Notarize and code sign the application via Apple's Developer ID program (if possible)" and "Sign the published update archive... with Sparkle's EdDSA signature" and shallow TLS (source: docs — step 3 "Segue for security concerns").
- Where EdDSA signing is **required** is for `SUVerifyUpdateBeforeExtraction` (validate before extraction) and for `SURequireSignedFeed` (validates appcast + release notes) (source: docs/customization + CHANGELOG 2.9). Key rotation is allowed if your app is **both** Developer ID code-signed AND includes an EdDSA key.
- For an unsigned / ad-hoc-signed app, Sparkle **still operates**. Source: the code-signing verification has an explicit path for when the host has "no valid Apple Code Signing" it logs error `SUInsufficientSigningError` but the flow proceeds with EdDSA validation of the archive (source: `Autoupdate/SUCodeSigningVerifier.m`, e.g. `errSecCSUnsigned` branch). The docs confirm "Note that Apple's code signing checks are not intended for complete integrity" and that "applying updates without a EdDSA signature/key is now deprecated" (source: `Documentation/Security.md`). So the honest claim: **Sparkle does not refuse unsigned apps; it relies on EdDSA of the archive as the real integrity control, and code-signing as a layered check.**
- **Gatekeeper:** Sparkle does not bypass Gatekeeper. For an unsigned, non-notarized app, the OS Gatekeeper will still present the "unidentified developer" warning when the (replaced) app first launches after update, unless the user has already approved or you've Developer ID-signed/notarized. Sparkle will run `gktool scan` so the "Verifying..." step is skipped, but the signedness warning persists.

### UI + automatic-check behavior
- `SUEnableAutomaticChecks`: default is prompt-on-second-launch (user grants permission, then automatic checks enable). Set `YES` to enable automatic checks without asking; `NO` to disable.
- `SUScheduledCheckInterval`: default **86400 (1 day)**, minimum bound 1 hour.
- `SUAutomaticallyUpdate`: default **NO**. Set YES to silently download+install in the background; may still need authorization for elevated installs.
- `SUScheduledImpatientCheckInterval`: default 604800 (1 week); after an update staged, if the user hasn't quit within it, they may be notified (config from 2.9).
- `SUAllowsAutomaticUpdates`: default lets users choose auto-download/install.

---

## 3. Custom updater deep-dive

This is the "we don't want a framework" path. **Stats** implements exactly this and is the closest primary source to what Pomodoro needs. Verified from `https://github.com/exelban/stats`:

```swift
// Kit/plugins/Updater.swift (excerpt, real source)
self.github = URL(string: "https://api.github.com/repos/\(github)/releases/latest")!
...
let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
guard let jsonArray = jsonResponse as? [String: Any],
      let lastVersion = jsonArray["tag_name"] as? String,
      let assets = jsonArray["assets"] as? [[String: Any]],
      let asset = assets.first(where: {$0["name"] as? String == "\(self.appName).dmg"}),
      let downloadURL = asset["browser_download_url"] as? String
```

### GitHub Releases API (primary: docs.github.com)
- Endpoint: `GET /repos/{owner}/{repo}/releases/latest`. Returns "the most recent non-prerelease, non-draft release, sorted by the `created_at`". (source: https://docs.github.com/en/rest/releases/releases).
- JSON shape: release = `{ tag_name, name, assets:[...], draft, prerelease, ... }`. Each asset: `{ name, browser_download_url, download_count, ... }`. (Quote: "`browser_download_url`: required, string, format: uri" and "`name`: required, string"). For a full list use `GET /repos/{owner}/{repo}/releases` (pagination: `per_page` default 30, max 100; drafts only visible to users with push access) (source: same page).
- Accept header: `Accept: application/vnd.github+json` (source: same page). A content-type is preferred; the API is public without auth at 60 req/hr/IP unauthenticated (source: https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api; "The primary rate limit for unauthenticated requests is 60 requests per hour.").
- Asset download: the `browser_download_url` is a `https://github.com/.../releases/download/<tag>/<file>` URL that 302-redirects to a **signed** `release-assets.githubusercontent.com` URL, with `Content-Disposition: attachment`. (verified with `curl -I` for `thanhqng1510/pomodoro-bar` v0.0.2: HTTP/2 302 -> `release-assets.githubusercontent.com/...?...&sig=...&jwt=...`, then HTTP/2 200 with `content-disposition: attachment; filename=...`.)

### Compare versions
- Your release tags are plain `0.0.1`, `0.0.2` (string, API returns `"tag_name":"v0.0.2"`). Compare with an integer semver parser (split `.`), or keep a build number; Apple's `CFBundleVersion` is what Sparkle compares. You must decide bytes if you want correctness.

### Download + checksum
- Download via `https://releases/download/<ver>/PomodoroBar-<ver>.zip` (already built in `install.sh`).
- Verify SHA-256 against `checksums.txt` (the workflow writes `shasum -a 256 dist/PomodoroBar-$VERSION.zip > dist/checksums.txt`) BEFORE installing. Note the current `checksums.txt` content is a single line with a trailing `dist/` path prefix (`5d6e2c491...53dist/PomodoroBar-0.0.2.zip`) — `install.sh`'s grep+awk already tolerates this. (verified live via API: asset `checksums.txt`, 93 bytes = `<hex>\ndist/PomodoroBar-0.0.2.zip\n`).

### Replace a running app at /Applications (the core problem)
- A running app bundle can't be overwritten in place (the kernel holds the executable mapped; and macOS translocation protections). Two patterns:
  - **Detached helper script (Stats):** The app can't die mid-update, so Stats launches a detached `updater.sh` (copied to `$TMP`/tmp with exec perms, passed the app path, dmg path, mount point, target UID), then calls `exit(0)`. The helper: mounts the dmg, validates the code signature with `SecStaticCode`/team ID, copies the app to a staging dir, moves the old app to a `.Stats-old`, moves the new app into place, then relaunches the new executable (optionally via `launchctl asuser` to run as the original user if it ran as root). See `Kit/scripts/updater.sh` step 2-3.
  - **Staged atomic swap (Sparkle):** the privileged `Autoupdate` installer does an atomic rename/swap where allowed, else moves to staging and swaps.
- `updater.sh` is the realistic pattern for Pomodoro: it runs the whole replace after the GUI exits, so no "running bundle" conflict. If it needs admin to write /Applications, it re-runs with `AuthorizationExecuteWithPrivileges` (deprecated but still usable inside the app due to needing the app to prompt for a password) — Stats does this.
- **Reopening the app:** Stats calls the executable directly (or `launchctl when told). You can also use `open` (launch the `.app`), which is what pomodoro's README already documents (`open -a PomodoroBar`). Use `NSWorkspace.open(URL(...))` in-process or shell out to `open`.
- **Apple-side of replacing an /Applications build:** the moved/renamed app is treated by the OS as a freshly-copied item. Because it's a fresh zip extraction + copy, Gatekeeper may apply quarantine on first launch (quarantine attribute propagation via translocation). Your updater should `codesign --force` as in `install.sh` + call `gktool scan` (macOS 14.4+) to pre-warm Gatekeeper, and be prepared that an **unsigned/non-notarized** build will still show the "unidentified developer" warning on first run after update. There's no way around that for an unsigned build.

---

## 4. Security (primary sources)

### Apple Gatekeeper / notarization (source: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- **Notarization is optional but very consequential**: "Beginning macOS 10.14.5, software signed with a new Developer ID cert and all new kernel exts must be notarized to run. From macOS 10.15, all software built after 2019-06-01 and distributed with Developer ID must be notarized." You are **not** required to notarize software distributed through the Mac App Store; but for direct distribution, if you want your app to run without Gatekeeper ceremony you must be Developer ID signed **and** notarized.

> **Example of the official model:** $100/yr Apple Developer Program, produce Developer ID certs, sign with `codesign --options runtime` — it is one-time and lets Gatekeeper output show "Apple notarized the software."

### What a naive custom updater enables an attacker to do
- If you fetch over plain HTTP (or resolve DNS/CAs fall-back), a **MITM attacker can substitute a malicious zip** (or a malicious `browser_download_url`). Even over HTTPS, an attacker with control of your *hosting/serving* (or a CDN cache, or a stolen signing cert) can serve a malicious update. DNS spoofing + plain HTTP = trivially exploitable. Over HTTPS without a signature check, the attacker still can't forge TLS, but they **can** exploit a hijacked connection if you don't pin/verify.
- GitHub Releases are HTTPS-only and the asset URL is signed — that reduces MITM, but the **transport plus** trustworthy identity is what protects you in the TLS layer. That does *not* protect against a compromised repo/server or a signed (stolen key) attacker.

### Sparkle's threat model (source: Documentation/Security, SUCodeSigningVerifier, Installation)
- **Privilege separation:** updater/downloader/installer/progress in separate processes; no `AuthorizationExecuteWithPrivileges` in its install path (it submits to `launchd`).
- **Spoofed feeds:** an attacker who compromises the update server cannot present a fake update that passes EdDSA; the archive is EdDSA-signed and keychecked against `SUPublicEDKey`.
- **Unsigned updates:** deprecated but still possible; Sparkle logs/errors on missing code-signing and falls back to EdDSA (`SUCodeSigningVerifier`).
- **Downgrade attacks:** Sparkle refuses updates that downgrade the version (`SUDowngradeError`), and `sparkle:minimumUpdateVersion`/`sparkle:minimumSystemVersion` gate incompatible updates (docs/publishing; SUPlainInstaller).
- **With GitHub, the equivalent defense for a custom updater:**
  - Serve HTTPS (GitHub is HTTPS; always).
  - **Verify a strong checksum**: your workflow already publishes SHA-256 `checksums.txt`. An attacker who cannot forge the release archive nor the checksums.txt (both HTTPS-served from your GitHub repo, which requires repo write access) cannot pass the check. This is your retro-spoofing defense.
  - Consider **code-sign validation** (Stats's `validateAppSignature` compares the new app's team ID/ou to the current app's), but that requires the copy actually to be Developer ID signed — which Pomodoro is not today. Without a signature you must rely on the HTTPS source + checksums.

### Authentication of GitHub releases
- The GitHub REST API is HTTPS. Public repos don't need a token; your updater should just respect rate limits (60/hr unauth). A GET is authenticated at the TLS layer by GitHub's certs. The "feed" here is trustworthy *as served by api.github.com*, and the archive by `release-assets.githubusercontent.com`. An attacker who (D)AI controls the machine, certs, or your GitHub account is out of scope.

---

## 5. Real-world apps verified from source

- **Ice** (`jordanbaird/Ice`, menu bar manager) — **uses Sparkle**. Verified directly in its repo: `Ice.xcodeproj/project.pbxproj` contains `XCRemoteSwiftPackageReference "Sparkle"` with `repositoryURL = "https://github.com/sparkle-project/Sparkle"`, and `Package.resolved` pins `"sparkle": 2.6.4` (source: https://github.com/jordanbaird/Ice tree). Distribution: manual `Ice.app` download + Homebrew cask; README does *not* mention notarization/@Developer-ID.
- **Stats** (`exelban/stats`, menu bar system monitor) — **custom updater**, not Sparkle. Verified source: `Kit/plugins/Updater.swift` builds `https://api.github.com/repos/.../releases/latest`, parses `tag_name`/`assets`/`browser_download_url`, downloads the `.dmg`, mounts, validates code signature by Team ID, launches `updater.sh`. README documents "https://api.github.com – Fallback for update checks" (source: repo). 
- **Hidden Bar** (`dwarvesf/hidden`, menu bar organizer) — README states distribution outside App Store is **notarized** ("The Hidden Bar is notarized before…"). No Sparkle references found in the repo tree/files I could read; the repo is SwiftUI/modern (source: tree listing + README). (Note: the original "Hidden Bar" may be a *different repo*; I could not verify.)
- **Apple's own model** (from §4): App Store update service is internal; for others there's no first-party updater API.

So: **two of the most comparable menu-bar apps use the two-options you're considering.** Stats is the near-exact analogue of Pomodoro Bar (menu bar, Swift it, GitHub/Homebrew distribution, unsigned).

> **Unverified:** Despite many blog claims that "Hidden Bar uses Sparkle", I could not confirm Spark in `dwarvesf/hidden` from its public tree; the repo appears to use a modern SwiftPM setup. Flag as unverified.

---

## 6. macOS 26 / Tahoe and 2025-26 news

- **Sparkle 2.8.0 added explicit "UI modernization and macOS Tahoe support"** (CHANGELOG entry) and the 2.9 line is current (source: repo CHANGELOG, releases).
- **macOS Tahoe 26 release notes** (Apple): relevant to updater networking — "For apps linked on or after iOS 26 / macOS 26, the default minimum TLS version of `URLSession` and Network framework has changed from 1.0 to 1.2." Your updater's code path must support TLS 1.2+ (GitHub already requires 1.2+, so a normal `URL`/`curl` is fine) (source: https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes — alternatively the .md mirror at /tutorials/data/documentation/...).
- **macOS 26.4 release notes:** Rosetta support ends after macOS 27; from 26.4, users are warned when launching Rosetta-based apps; macOS Tahoe 26 is the last Intel-capable release (source: https://developer.apple.com/tutorials/data/documentation/macos-release-notes/macos-26_4-release-notes.md). Not auto-update-specific, but relevant context for arm64-only Pomodoro target.
- **No primary source found** for a Tahoe-specific Gatekeeper policy change that alters how unsigned apps update or are relaunched. Treat Gatekeeper/bang/notarization behavior as unchanged for this purposes. (I checked Apple docs index + Tahoe release notes; if a change exists it's not public yet or lives in Apple news that requires login.)
- **Gatekeeper / quarantine mechanics remain:** an app that is not Developer ID signed shows the "unidentified developer" prompt on first launch; notarization gives the Apple "checked for malicious components" ticket, which Gatekeeper places in the launch dialog (source: Apple notarization doc link).

---

## 7. What this means for Pomodoro Bar

Constraints recap:
- macOS 26, SwiftUI menu bar app, Xcode 26.6, **not sandboxed**, **not Developer ID signed** (ad-hoc at install), **not notarized**, arm64-only.
- Already publishes GitHub Releases zip + SHA-256 `checksums.txt` from a two-job CI workflow triggered on a `v*` tag. Version = plain string.
- Low ceremony (chose curl over Homebrew).

### Realistic option A — Sparkle 2.x (recommended if you want a framework)
**Fit:** macOS 26 runtime OK; unsandboxed so no XPC service wiring; doesn't require your app to be signed; EdDSA gives you the integrity you lack today.
**Work:** (1) add `Sparkle.framework` (SwiftPM or Carthage — see docs), (2) add `SUFeedURL` (appcast) + `SUPublicEDKey`; (3) set `SUEnableAutomaticChecks` / `SUAutomaticallyUpdate`; (4) generate an EdDSA key (Keychain) and sign your archive with `sign_update`/`generate_appcast` in your release workflow. You must also adopt an **appcast** (XML) hosted somewhere with the current zip + EdDSA sig (can be a static file in a repo / the GitHub Release's raw XML). The workflow already produces the zip; add `sign_update` to stamp the feed and the archive each release.
 * You keep your curl installer for first-time install; Sparkle only handles subsequent updates so a user is on 0.0.1.
 * Because the app is unsigned/non-notarized: the new version on disk still triggers Gatekeeper's "unidentified developer" once after the swap, even though Sparkle will run `gktool scan` to avoid the "Verifying..." step. Verify users who already right-click-Opened to run it will pass without re-warning (they've approved the bundle identifier), but a fresh-ish permission may still appear.
 * Most robust: sign Developer ID + notarize; then Sparkle's `gktool` scan + notarization gives clean launches. But that adds Apple dev program cost/ceremony, contradicting Pomodoro's low-ceremony bias.

### Realistic option B — custom updater (mirror `install.sh`)
 * Directly reuses your existing JSON schema + checksums. This is the **Stats-proven** path and the smallest new surface in-repo.
 * Component list:
   1. On 1st launch+gond, or an "Check for Updates" menu item, call `GET https://api.github.com/repos/thanhqng1510/pomodoro-bar/releases/latest` (Accept header; cache 1/day — rate limit).
   2. Compare `tag_name` (strip `v`) to your current version → if newer: fetch `checksums.txt`, download `PomodoroBar-<ver>.zip` from the same release's base URL, `verify SHA-256` before touching anything.
   3. **Replace running app.** Ship a tiny detached helper (a `launchd`-style script or a small Swift CLI) that survives your process exiting:
      - copy new zip's `.app` to a staging dir beside the app;
      - terminate/quit your GUI (the app exits itself after launching the helper);
      - swap old → `../PomodoroBar.old`, new → `/Applications/PomodoroBar.app` (atomic rename), optionally with `sudo` (this re-runs the prompt) if the current user can't write to /Applications — same flow as `install.sh`'s `sudo -p` logic.
      - relaunch the new executable (or `open`).
   4. Optionally `codesign --force --sign -` the new bundle (as your `install.sh`) and run `gktool scan` to pre-warm Gatekeeper.
 * Security: HTTPS + SHA-256 (from the release's checksums.txt) is identical to Sparkle's EdDSA-advisory in spirit; you "trust GitHub's serving + your own verifier". No key to maintain. You **cannot** do code-signature team-ID validation because the app isn't signed — so the checksum is your integrity anchor. Consider serving `checksums.txt` tightly (raw.githubusercontent takes the release's exact content), which the workflow already does.
 * Tradeoff: you own every edge (relaunch timing, translocation re-quarantine, failure rollback, admin prompts). Sparkle would have solved most of these.

### Trade-off summary
| Option | Dev / ceremony | Code in repo | Security posture | Fits "unsigned + GitHub + low ceremony"? | Risk you own |
|---|---|---|---|---|
| Sparkle | Medium | ~integration | High (EdDSA) | Partial — needs appcast + EdDSA + possibly not going notarized | Signing-key custody |
| Custom updater | Small-to-medium | ~「install.sh」+ updater helper | Depends on your checksum discipline | **Yes** | Relocation/swap, reddits, rollback, admin |

**Recommendation:** For the app's current constraints the **custom updater is the lower-ceremony, lowest-dependency** answer (you already have `install.sh`, checksums, and the API). Follow **Stats'** detached-helper + swap + relaunch pattern, verify `checksums.txt` SHA-256 over HTTPS, and treat the "can't be notarized" gate as an active UX cost until you decide to invest in Developer ID + notarization (which is the only thing that removes the Gatekeeper prompt entirely). If you'd rather not own update reliability, Sparkle 2.x is the framework answer, and its only non-obvious requirement fits your case exactly: `sparkle:hardwareRequirements>arm64` + a per-release EdDSA signature next to your existing zip/checksums.

---

## 8. Option C — let Homebrew handle updates (distribution-level)

Idea: ship a cask, never write updater code; `brew upgrade` does download → verify → quit → replace.

### What `brew upgrade --cask` actually does
- A cask pins the exact `url`, `version`, and `sha256` of your zip (the Cask Cookbook's own first example is a GitHub-Releases zip cask — `anybar`, a menu bar app, structurally identical to Pomodoro's artifacts) (source: https://raw.githubusercontent.com/Homebrew/brew/master/docs/Cask-Cookbook.md — "sha256" stanza: "SHA-256 checksum of the file downloaded from `url`…"). On upgrade, brew downloads the pinned URL, verifies it against the pinned sha256, and fails on mismatch — so you get the same integrity guarantee as `checksums.txt`, maintained by the cask itself.
- Replacing a running app: casks declare `quit` (Apple Event quit) / `signal` stanzas so brew can stop the running app before swapping the bundle (source: same Cookbook — `uninstall` `quit:`/`signal:` + `on_upgrade:`; "signal: directives are skipped during `brew upgrade`… to opt a cask into running this directive during an upgrade or reinstall, use `on_upgrade: :signal`").
- Homebrew is **user-initiated only**: brew is a CLI with no background agent — updates happen when the *user* runs `brew upgrade` (nothing in the docs describes any automatic cask refresh; third-party tools like `brew autoupdate` exist precisely because core brew doesn't do this). Your app cannot push an update or even show an in-app "new version" banner unless you add a tiny version check yourself.

### Getting into a tap
- **Official `homebrew/cask` is not realistic for Pomodoro today**: new packages must show notability — "at least 30 forks, 30 watchers or 75 stars" (or "90 forks, 90 watchers or 225 stars for a self-submission by the repository owner"), and "a code repository less than 30 days old is normally not eligible" (source: https://raw.githubusercontent.com/Homebrew/brew/master/docs/Package-Acceptance-Policy.md — "Notability"). The repo is currently far below those bars.
- **A personal tap (e.g. `thanhqng1510/homebrew-tap`) is the realistic path**: your tap, your rules — no notability review and no signing requirement enforced. The Cookbook even defines an `unsigned_accessibility` caveat for unsigned apps ("Users will need to re-enable the app on each update in System Settings → Privacy & Security… as it is unsigned") (source: Cookbook, caveats table) — i.e., unsigned casks are a known, supported (if second-class) case.
- Policy context for official taps (if ever relevant): casks "must work on the latest major version of macOS" and "must not require System Integrity Protection or Gatekeeper to be disabled or bypassed" (source: https://raw.githubusercontent.com/Homebrew/brew/master/docs/Acceptable-Casks.md). Nothing in the current policy hard-requires Developer ID signing or notarization for acceptance.

### Costs and gaps
- **Per-release cask bump**: each release needs `version` + `sha256` updated in the tap. This is scriptable — a step in `release.yml` that commits the bumped cask to the tap repo after publishing (the release job already has the version and checksum in hand).
- **Coverage gap**: only users who installed via brew get updated. Existing `install.sh` users are untouched — you'd keep the curl installer (or ask users to migrate).
- **Gatekeeper unchanged**: brew does not sign or notarize; first launch of each new version still shows the "unidentified developer" prompt for an unsigned app (same as options A/B — only Developer ID + notarization removes it).
- **No in-app awareness**: the app can't tell the user "update available"; discoverability depends on the user's `brew upgrade` habit.

### Verdict
Option C is real and zero-code-in-app, but it converts "auto-update" into "user-run update": the entire update UX becomes `brew upgrade`, and only for the brew-installed subset of users. It pairs naturally with keeping `install.sh` for first install. If "app tells me / updates itself" matters, C alone doesn't deliver it; C + a 20-line version-check banner (GitHub API compare → "run `brew upgrade`" hint) covers most of the gap with none of the self-replacement machinery.

---

## Sources

Primary / first-party (all used):
- Sparkle repo README + branch `2.x` — https://github.com/sparkle-project/Sparkle (README.markdown raw: https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/README.markdown )
- Sparkle docs (site) — https://sparkle-project.org/documentation/ and subpages:
  - Setup / signing / EdDSA — https://sparkle-project.org/documentation/#setup (and step-3 Securing)
  - Publishing + appcast schema — https://sparkle-project.org/documentation/publishing/
  - Sandboxing (XPC services) — https://sparkle-project.org/documentation/sandboxing/
  - Customization (auto-check + Info.plist keys) — https://sparkle-project.org/documentation/customization/
  - App Transport Security — https://sparkle-project.org/documentation/app-transport-security/
  - About (feature list/usecase) — https://sparkle-project.org/about/
- Documentation in-repo (primary):
  - `Documentation/Security.md` — https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/Documentation/Security.md
  - `Documentation/Installation.md` — https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/Documentation/Installation.md
  - `Documentation/Design Practices.md` — https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/Documentation/Design%20Practices.md
  - `CHANGELOG` — https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/CHANGELOG
  - `Resources/SampleAppcast.xml` (appcast example) — https://raw.githubusercontent.com/sparkle-project/Sparkle/2.x/Resources/SampleAppcast.xml
  - `sign_update/main.swift`, `generate_keys/main.swift` (tooling) — rawgithubusercontent URLs
  - Source: `Autoupdate/SUCodeSigningVerifier.m`, `Autoupdate/SUPlainInstaller.m`, `Autoupdate/AppInstaller.m` — raw.githubusercontent
- Sparkle releases (GitHub API) — https://api.github.com/repos/sparkle-project/Sparkle/releases
- GitHub Releases REST API docs (latest release, JSON `tag_name`/`assets`/`browser_download_url`) — https://docs.github.com/en/rest/releases/releases
- GitHub REST rate limits — https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
- Apple notarization (Gatekeeper/Developer ID) — https://developer.apple.com/documentation/security/notarization (equivalently https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution md: https://developer.apple.com/tutorials/data/documentation/security/notarizing-macos-software-before-distribution.md)
- Apple resolving notarization issues — https://developer.apple.com/documentation/security/resolving-common-notarization-issues (markdown: .../resolving-common-notarization-issues.md )
- macOS 26 Release Notes (TLS 1.2 default) — https://developer.apple.com/tutorials/data/documentation/macos-release-notes/macos-26-release-notes.md
- macOS 26.4 Release Notes (Rosetta/Intel notice) — https://developer.apple.com/tutorials/data/documentation/macos-release-notes/macos-26_4-release-notes.md
- Stats (custom updater, menu bar) — https://github.com/exelban/stats
  - Source: `Kit/plugins/Updater.swift` — https://raw.githubusercontent.com/exelban/stats/master/Kit/plugins/Updater.swift
  - Source: `Kit/scripts/updater.sh` — https://raw.githubusercontent.com/exelban/stats/master/Kit/scripts/updater.sh
  - README (both API URLs) — https://github.com/exelban/stats
- Ice (Sparkle) — https://github.com/jordanbaird/Ice
  - `Ice.xcodeproj/project.pbxproj`, `Package.resolved` — raw.githubusercontent URLs
- Squirrel.Windows (seeking maintainers) — https://github.com/Squirrel/Squirrel.Windows
- Squirrel.Mac (tag 0.3.2 and README) — https://github.com/Squirrel/Squirrel.Mac
- Hidden Bar (dwarf/distribution note) README — https://github.com/dwarvesf/hidden
- Homebrew docs (option C, §8):
  - Acceptable Casks — https://raw.githubusercontent.com/Homebrew/brew/master/docs/Acceptable-Casks.md
  - Package Acceptance Policy (notability bars) — https://raw.githubusercontent.com/Homebrew/brew/master/docs/Package-Acceptance-Policy.md
  - Cask Cookbook (sha256/quit/signal stanzas, `unsigned_accessibility`, anybar example) — https://raw.githubusercontent.com/Homebrew/brew/master/docs/Cask-Cookbook.md
- Pomodoro Bar (target) — local repo:
  - `install.sh`, `.github/workflows/release.yml`, `README.md`, `TimerModel.swift`
  - live releases via https://api.github.com/repos/thanhqng1510/pomodoro-bar/releases/latest (assets: `checksums.txt` content bytes, `PomodoroBar-0.0.2.zip`, HTTP header/302 behavior verified with `curl -IL`).