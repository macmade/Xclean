# Changelog

## Unreleased

Changes by Luis Hernandez <luisrh@mac.com>.

- Updated the Xclean target to build with Swift 5.0 and a modern macOS deployment target.
- Modernized derived-data icon lookup to use `UniformTypeIdentifiers` and `NSWorkspace.icon(for:)`.
- Made the menu bar status item more reliable by loading the PDF icon directly, sizing it explicitly, and providing a visible fallback title.
- Fixed popover behavior so clicking the menu bar icon opens the view and keeps it open until AppKit dismisses it as a transient popover.
- Suppressed noisy Debug-scheme OS activity logs from Apple App Intents/CoreSpotlight registration that are unrelated to this app.
