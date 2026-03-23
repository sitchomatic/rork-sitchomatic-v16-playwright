# Part 1: OLED Cyberpunk UI Redesign — Dashboard, Tab Bar, Main Menu & Session Cards


## Overview
Complete UI overhaul of the app to match the cyberpunk monitoring aesthetic from the inspiration images. This is **Part 1 of 2** — covering the Dashboard, Main Menu/Tab Bar, Session Cards, and shared design system.

---

### **Design System (NeonTheme)**
- A shared color/style utility used across all screens
- True black (`#000000`) backgrounds throughout — optimized for OLED
- Neon green (`#00FF66`) as the primary accent for active/healthy states
- Cyan (`#00E5FF`) for secondary highlights, progress, and interactive elements
- Magenta/red for errors, orange for warnings, indigo for "no account"
- All cards use a frosted glassmorphism effect — dark translucent backgrounds with subtle bright borders
- Monospaced fonts (SF Mono) for data-heavy elements, SF Pro for labels
- Neon glow effects on key indicators using shadow layers

---

### **Main Menu / Tab Bar**
- True black background behind the entire tab view (replaces wallpaper overlay)
- Custom-styled bottom tab bar with 5 tabs: **Dashboard**, **Runs**, **Credentials**, **Debug**, **Settings**
- Tab icons use distinct SF Symbol glyphs with neon green tint when selected, dim gray when inactive
- Tab bar uses ultra-thin material with a subtle top border line in dark green
- The wallpaper is removed from the tab-level background — each screen owns its own black canvas

---

### **Dashboard — Complete Redesign**

**Top Header — Pairs Status Bar**
- Full-width header showing "Pairs Status" with large neon green count (e.g., `23/50`)
- A glowing neon green progress bar beneath the count
- "Processing" label with a pulsing dot indicator when engine is active
- Connection badge (LIVE/OFF) with neon glow in the top-right corner

**Health Ring**
- Large centered circular health gauge (like the 100% ring in the inspiration)
- Neon green ring when healthy, degrades to orange/red
- Center text shows percentage + "Active" / "Idle" state label
- Subtle outer glow effect on the ring

**Quick Stats Grid**
- 4×3 or similar grid of compact stat tiles surrounding the health ring
- Each tile shows a number + subtitle (e.g., "68 / 2021")
- Tiles use dark card backgrounds with neon green text for values
- Stats include: succeeded, failed, active, queued, no acc, perm disabled, temp disabled, unsure, error, credentials, pairs, concurrency

**Quick Action Buttons**
- Row of 4 icon buttons: Credentials, Pairs, Health, Sessions
- Dark rounded square backgrounds with colored SF Symbol icons
- Badge overlay (e.g., pair count) on relevant buttons

**Result Category Gauges**
- Row of mini gauge/speedometer-style indicators for each result category
- Success (green), Failed (red), Active (cyan), Queued (gray)
- Second row: No ACC (indigo), Temp Disabled (orange), Perm Disabled (red), Error (yellow)
- Each shows the count below with category name

**System Health Section**
- "System Health Waveform" — a faux audio waveform visualization showing recent activity
- "Memory Status" — circular gauge showing memory percentage
- Both in dark glassmorphism cards side-by-side

**Tools Section**
- Dual Find and Recorder cards remain, restyled with dark glass aesthetic and neon icon accents

---

### **Session Cards — High-Density Feed Redesign**

Each session card in the scrolling feed is redesigned to match the inspiration:

**Card Header**
- Email/username as the headline in white, bold
- Small context menu button (three dots) in top-right corner

**Dual Feed Side-by-Side**
- Two mini panels labeled "**Joe**" and "**Ignition✓**" side by side
- Each shows a dark placeholder area for the screenshot proof
- "Joe" text in large white bold, "Ignition✓" with brand styling
- If screenshots exist, they fill the respective panels

**Multi-State Progress Bar**
- A segmented progress bar below the dual panels
- Neon green for the completed/healthy portion
- Cyan, magenta, or orange "tail" segments for different backend states
- Represents session progress visually

**Live Caption**
- "Live status:" text in gray followed by a color-coded status message
- Green for active, cyan for parsing, yellow for warnings
- Real-time status updates (e.g., "Parsing details for [Session ID: B]")

**Footer Metrics**
- Small "Conn: 1 / Sys: 1" connection indicator in bottom-right
- Wave index and elapsed time

**Action Buttons**
- Retry, Copy, Flag buttons appear for terminal sessions
- Styled as small bordered buttons with neon accent tints

---

### **Session Filter Bar**
- Horizontal scrolling filter chips above the session feed
- Dark capsule backgrounds, neon green border + text when selected
- Shows count badges for each filter category

---

### **Files Changed**
This part will create/modify:
- New shared `NeonTheme.swift` design system utility
- Redesigned `MainMenuView.swift` with dark tab bar
- Completely rewritten `DashboardView.swift` with all new sections
- New `HealthRingView.swift` — reusable circular gauge component
- New `StatTileView.swift` — compact stat tile component
- New `SessionCardView.swift` — extracted high-density session card
- New `WaveformView.swift` — faux waveform visualization
- New `NeonProgressBar.swift` — multi-state progress bar component
- New `GaugeIndicatorView.swift` — mini speedometer gauge

Part 2 (next reply) will cover: **Dual Run View, Credential Manager, Debug Console, Settings, Session Proof Sheet, and Full Timeline** — all restyled to match this same OLED cyberpunk aesthetic.
