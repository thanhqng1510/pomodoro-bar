/// App version, stamped into source by `set-version.sh` at release build time.
/// The git tag is the single source of truth: CI reads the tag and replaces the
/// value below before building. Kept in sync with `MARKETING_VERSION` so the
/// generated Info.plist and the in-app updater agree.
enum AppVersion {
  static let current = "0.0.1"
}