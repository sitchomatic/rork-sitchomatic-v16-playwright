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

# Section 5: Recorder, Dual Find, and PPSR Integration Polish

## Section 5 of 5 — Tooling Completion + Artifact Persistence

### Completed

- [x] Rebuild Dual Find into a selector probe with site presets powered by `AutomationSite` and persisted site URLs
- [x] Add selector-family presets for username, password, and submit targeting Joe Fortune and Ignition Casino
- [x] Capture proof screenshots during Dual Find runs and persist JSON + PNG artifacts into tool storage
- [x] Surface PPSR status directly in Dual Find with storage usage, checkpoint visibility, and saved artifact paths
- [x] Rebuild Flow Recorder into a script studio with mode selection, quick inserts, undo, copy, save, and preview controls
- [x] Add recorded preview execution from Flow Recorder into `ConcurrentAutomationEngine` via `WaveConfig`
- [x] Persist recorder manifests and generated Swift scripts into tool storage for later inspection
- [x] Promote tool saves and probe events into the `DebugLogger` PPSR category for easier debugging
- [x] Keep future site expansion simple by driving tool presets from `AutomationSite.allCases`
- [x] Update project documentation to reflect the full app, architecture, tools, storage, and automation flow
- [x] Verify the iOS app compiles successfully after the Section 5 changes

### Design

- [x] Keep the tools native and operational instead of web-like utility panes
- [x] Use material cards, clear hierarchy, and compact monospaced detail where it improves diagnostics
- [x] Keep proof, metadata, and recovery visibility close to the action that generated them
- [x] Favor direct manipulation: one tap to insert a selector scaffold, one tap to probe, one tap to preview

### Files Changed

- [x] `ios/Sitchomatic/Views/DualFind/DualFindContainerView.swift` — selector probe presets, proof capture, and PPSR artifact visibility
- [x] `ios/Sitchomatic/Views/FlowRecorder/FlowRecorderContainerView.swift` — script studio UI, quick inserts, save/copy flows, and recorded preview controls
- [x] `ios/Sitchomatic/Services/RecordingSession.swift` — Codable recorded actions plus undo support for tool composition
- [x] `README.md` — full app documentation refresh covering architecture, services, tools, and storage

## Post-Section Hardening: Playwright Networking + Isolation

### Completed

- [x] Research current Playwright actionability, auto-waiting, and isolation guidance before hardening the runtime
- [x] Replace fragile timing assumptions with stronger actionability polling and stable-element checks in `Locator`
- [x] Improve post-action and post-submit settling so navigation and async page updates are observed before classification
- [x] Tune speed-mode profiles with dedicated navigation, selector, polling, stability, and retry parameters
- [x] Strengthen login outcome detection to rely less on fixed waits and more on URL/content state changes
- [x] Route per-session WebViews through isolated non-persistent WebKit stores with separate process pools
- [x] Ensure paired sessions can share the same proxy endpoint without sharing cookies, local storage, history, or viewport state
- [x] Keep concurrent runs safer by deriving network configuration per session instead of reusing broad global page state
- [x] Verify the iOS app compiles successfully after the Playwright hardening work

### Files Changed

- [x] `ios/Sitchomatic/Models/SpeedMode.swift` — expanded timing and retry controls for more reliable automation pacing
- [x] `ios/Sitchomatic/Services/Playwright/PlaywrightPage.swift` — improved navigation waiting, network-idle observation, and settle helpers
- [x] `ios/Sitchomatic/Services/Playwright/Locator.swift` — stronger actionability checks, stability polling, and interaction verification
- [x] `ios/Sitchomatic/Services/SiteLoginAutomationService.swift` — more resilient selector resolution and post-submit outcome observation
- [x] `ios/Sitchomatic/Services/WebViewPool.swift` — per-acquisition isolated WebKit configuration with cleanup guarantees
- [x] `ios/Sitchomatic/Services/SimpleNetworkManager.swift` — per-session network configuration lookup for proxy-safe isolation
- [x] `ios/Sitchomatic/Services/Playwright/PlaywrightOrchestrator.swift` — session-scoped WebView acquisition and stronger pair isolation logging

## Status

- [x] Section 5 — Recorder / DualFind / PPSR integration polish
- [x] Post-section Playwright networking, waiting, and isolation hardening
