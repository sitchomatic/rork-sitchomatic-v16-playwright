# Section 4: UI, Debug, Dual Run Visibility Improvements

## Section 4 of 5 — Advanced Navigation + Dashboard + Debug Visibility

### Completed

- [x] Replace the legacy tab configuration with the iOS 18 `Tab` API and typed tab selection
- [x] Add a typed `AppTab` model for safer navigation state across the main menu
- [x] Build a richer dashboard hero with quick jumps into Run, Credentials, and Debug
- [x] Add an overview grid for run state, results, background status, and recovery state
- [x] Add session visibility filters for all, active, failed, and succeeded sessions
- [x] Keep proof screenshots visible directly inside dashboard session cards
- [x] Keep proof screenshots visible directly inside dual run session rows
- [x] Add typed dashboard destinations for Dual Find and Flow Recorder entry points
- [x] Upgrade the debug console with diagnostics cards, log search, category filters, and severity filters
- [x] Add a live error badge to the Debug tab using recent logged errors
- [x] Promote `DebugLogger` to `@Observable` and add UI-friendly titles/all-cases for filters
- [x] Preserve native SwiftUI materials, semantic colors, and Apple-style hierarchy
- [x] Verify the iOS app compiles successfully after the Section 4 changes
- [x] Refresh the main menu shell with a full-bleed wallpaper backdrop and darker glass tab bar styling
- [x] Replace the main menu wallpaper asset with the latest uploaded cyberpunk artwork
- [x] Add a secure single-key WireGuard access key path backed by the device Keychain

### Design

- [x] Keep the cyberpunk wallpaper as the immersive dashboard backdrop
- [x] Use layered material cards instead of flat panels for depth
- [x] Surface session proof, run health, checkpoint state, and background time at a glance
- [x] Make the main menu feel closer to an advanced native operations dashboard than a basic tab shell
- [x] Keep the interaction model simple: tap a session for proof, tap a tool to drill in, tap a tab to move sections
- [x] Keep the tab shell visually consistent with the uploaded wallpaper while preserving native iOS navigation behavior

### Files Changed

- [x] `ios/Sitchomatic/Models/AppTab.swift` — typed tab model for the main app shell
- [x] `ios/Sitchomatic/Models/SessionVisibilityFilter.swift` — reusable session filtering model
- [x] `ios/Sitchomatic/Models/DashboardDestination.swift` — typed dashboard navigation destinations
- [x] `ios/Sitchomatic/MainMenuView.swift` — iOS 18 tab API, immersive wallpaper shell, debug badge, tab feedback
- [x] `ios/Sitchomatic/Views/DashboardView.swift` — advanced dashboard layout, hero card, overview grid, proof-first session list, quick navigation
- [x] `ios/Sitchomatic/Views/DualRunView.swift` — richer live overview, filterable sessions, proof visibility, improved run controls
- [x] `ios/Sitchomatic/Views/DebugContainerView.swift` — searchable diagnostics console with category and severity filters
- [x] `ios/Sitchomatic/Views/SettingsView.swift` — secure single-key WireGuard access key management and status visibility
- [x] `ios/Sitchomatic/Services/DebugLogger.swift` — observable logging model with case lists and display titles
- [x] `ios/Sitchomatic/Services/WireGuardAccessKeyStore.swift` — Keychain-backed storage for a single WireGuard access key
- [x] `ios/Sitchomatic/Assets.xcassets/MainMenuWallpaper.imageset/wallpaper.jpg` — refreshed wallpaper art

## Next

- [ ] Section 5 — Recorder / DualFind / PPSR integration polish
