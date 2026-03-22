# Section 3: Engine Hardening, Recovery, Memory Tuning + Main Menu Wallpaper

## Section 3 of 5 — Concurrent Engine + Recovery/Memory Tuning + Wallpaper

### Features

**Main Menu Wallpaper**

- Generate the uploaded Sitchomatic cyberpunk image as an app asset
- Set it as a full-bleed background on the Main Menu screen behind all cards
- Add a dark overlay gradient so the menu cards and status text remain readable
- Remove the plain system background and replace with the immersive wallpaper

**Crash Protection Service — Enhanced**

- Add adaptive memory threshold scaling based on crash history (more crashes → lower thresholds)
- Add automatic cooldown timer after crashes (prevents rapid re-launch of sessions)
- Add memory pressure level enum (safe / elevated / critical / emergency) for clearer state
- Add a method to suggest optimal concurrency based on current memory pressure

**Session Recovery Service — Upgraded**

- Add full wave-level checkpoint saving (which credentials completed, which failed, which are pending)
- Add ability to resume from the last saved checkpoint after a background kill
- Add automatic stale checkpoint cleanup (checkpoints older than 1 hour get purged)
- Track recovery success rate for diagnostics

**Background Task Service — Hardened**

- Add keep-alive ping loop that refreshes the background task before expiration
- Add graceful degradation: when background time is low, finish current wave then pause
- Track remaining background time and expose it for the dashboard

**WebView Lifetime Budget Service — Tuned**

- Add dynamic budget adjustment: if memory is high, reduce concurrent limit automatically
- Add per-wave budget tracking (track creations/destructions per wave for better diagnostics)
- Add budget reset option when engine completes or is manually stopped

**WebView Crash Recovery Service — Improved**

- Add crash pattern detection: if same page crashes repeatedly, blacklist that credential temporarily
- Add exponential backoff for recovery attempts
- Add recovery success/failure tracking

**Concurrent Automation Engine — Major Upgrades**

- Integrate enhanced crash protection: auto-reduce concurrency when memory is elevated
- Add smart wave scheduling: if previous wave had failures, insert longer cooldown
- Add credential result tracking: update credential success/fail counts after each run
- Persist attempt history via PersistenceService after each session completes
- Add engine health score (composite of memory, crash rate, success rate)
- Improve emergency state persistence with full session snapshot
- Add auto-pause when memory reaches critical threshold (resume when safe)

### Design

- Main Menu gets the cyberpunk Sitchomatic wallpaper as a full-screen background image
- Dark gradient overlay from bottom (80% opacity) fading to top (40% opacity) ensures readability
- Menu cards use `.ultraThinMaterial` over the wallpaper for a glass-card effect
- Status header gets a slightly stronger material backdrop for contrast
- The "SITCHOMATIC v16" title stays white/light for contrast against the dark wallpaper

### Files Changed

- **MainMenuView.swift** — Full wallpaper background with gradient overlay
- **CrashProtectionService.swift** — Adaptive thresholds, memory levels, cooldown timer
- **SessionRecoveryService.swift** — Full checkpoint system with resume capability
- **BackgroundTaskService.swift** — Keep-alive loop, graceful degradation
- **WebViewLifetimeBudgetService.swift** — Dynamic budget, per-wave tracking
- **WebViewCrashRecoveryService.swift** — Pattern detection, exponential backoff
- **ConcurrentAutomationEngine.swift** — Smart scheduling, auto-pause, credential tracking, health score
- **Generated image asset** — Sitchomatic wallpaper from uploaded image

