# DECISIONS.md — Architecture Decision Record (light)

Lightweight ADR. Each significant decision is recorded with:
Decision, Motivation, Alternatives considered, Why rejected, Consequences / trade-offs.

---

## D-001: Swift Package Manager + bundle script instead of hand-written xcodeproj

- **Decision:** v0.1 uses a Swift Package (`Package.swift`) plus a small reproducible
  build script (`scripts/build.sh` / `scripts/make-app.sh`) that assembles
  `MacPerformance.app` from the built binary.
- **Motivation:** No fragile hand-written `project.pbxproj`. Fully terminal-driven.
  Xcode opens `Package.swift` natively (satisfies "openable in Xcode").
  Reproducible from CLI with `swift build`. No external tooling required.
- **Alternatives considered:**
  - Hand-write `project.pbxproj`.
  - Use `xcodegen`/`tuist` to generate an xcodeproj.
- **Why rejected:**
  - Hand-written pbxproj is fragile, error-prone, and hard to maintain.
  - xcodegen/tuist are external tools requiring installation (project forbids
    arbitrary software / unnecessary external dependencies).
- **Consequences / trade-offs:** No native "Xcode project" file; opening the
  folder in Xcode shows the SPM package. App bundle must be assembled by a
  script (SPM does not emit a `.app` itself). This is acceptable and documented.

---

## D-002: gpuUsage is Optional (Double?)

- **Decision:** `SystemStats.gpuUsage` is `Double?`. A failed/unreadable GPU read
  produces `nil`, never `0`.
- **Motivation:** `0%` means "GPU is actually idle". "I cannot read the GPU" is a
  different state and must not be conflated with real 0% usage.
- **Alternatives considered:** defaulting to 0 on error; throwing; using a
  separate boolean flag.
- **Why rejected:** 0 would silently look like idle; a separate flag is more
  bookkeeping than an Optional.
- **Consequences / trade-offs:** UI must handle `nil` (renders `GPU —`).

---

## D-003: Memory "used" formula = active + wired + compressed

- **Decision:** used memory = active + wired + compressed (pages in use).
  inactive/speculative/free are intentionally excluded.
- **Motivation:** Semantically coherent approximation of physical memory truly
  in use. Inactive pages are reclaimable cache, not "used". Activity Monitor is
  used only as a sanity check, **not** a claim of byte-for-byte equivalence.
- **Alternatives considered:** used = total - free; adding inactive.
- **Why rejected:** "total - free" overcounts (includes reclaimable inactive as
  used); adding inactive contradicts the "in use" definition.
- **Consequences / trade-offs:** Value is an approximation of in-use memory,
  defensible and documented, not a replica of Activity Monitor.

---

## D-004: GPU reader uses IORegistry PerformanceStatistics on IOAccelerator service

- **Decision:** GPUReader reads the `PerformanceStatistics` dictionary from the
  `IOAccelerator` IOKit service via public `IORegistryEntryCreateCFProperty`.
- **Motivation:** The service is present on this M4 and exposes live
  `Device/Renderer/Tiler Utilization %` counters (driver-provided).
- **Alternative/Note:** `IORegistryEntryCreateCFProperty` is a public IOKit API.
  The specific keys ("Device Utilization %" etc.) are **driver/empirical
  properties, not a documented, stable Apple API contract**.
- **Why not WidgetKit / private APIs:** WidgetKit can't do 1s updates; private
  APIs avoided when a working public alternative exists.
- **Consequences / trade-offs:** Dependent on driver property names that could
  change across hardware/macOS. Fully isolated in `GPUReader.swift` for easy
  replacement. See ARCHITECTURE.md / README.md for compatibility risks.

---

## D-005: Why not WidgetKit for v0.1

- **Decision:** v0.1 is a plain SwiftUI + AppKit window, not a WidgetKit widget.
- **Motivation:** Requirement for ~1s updates and desktop persistence; WidgetKit
  refresh cadence is not suitable for live 1s metric updates.
- **Alternatives considered:** WidgetKit widget.
- **Why rejected:** refresh cadence / limitation on continuous live updates.
- **Consequences / trade-offs:** Not a true desktop widget; a regular window at an
  empirically chosen window level. A future version could add WidgetKit.

---

## D-006: Window level — empirically determined  (FINAL: kCGDesktopIconWindowLevel + 1)

- **Decision:** Window level = `kCGDesktopIconWindowLevel + 1` (raw -2147483602,
  i.e. `Int(CGWindowLevelForKey(.desktopIconWindow)) + 1`); strictly above
  Finder's desktop window and below `kCGNormalWindowLevel` (0). NOT always-on-top.
- **Motivation:** original choice `.desktop` / `kCGDesktopWindowLevel` FAILED:
  the widget was not visible on the desktop (D re-opened by user).
  Empirical stack on this Mac (macOS 26.6, back→front, from
  `CGWindowListCopyWindowInfo`):
  - -2147483626 Window Server (desktop base)
  - -2147483624 Dock `Wallpaper-…` (full-screen wallpaper window)
  - **-2147483623 kCGDesktopWindowLevel — original position → FAILED**
  - -2147483603 kCGDesktopIconWindowLevel — Finder's full-screen desktop window
    (1710×1107), always present; this is what hides the widget when below it
  - -2147483602 Window Server menu-bar strip + Notification Center widgets layer
  - 0 = kCGNormalWindowLevel and above → normal application windows
- **Candidates tested (with MP_WINDOW_LEVEL env override, documented below):**
  - A) `kCGDesktopWindowLevel` (-3623): layer strictly below Finder desktop →
    widget hidden. REJECTED.
  - B) `kCGDesktopIconWindowLevel` (-3603): equal to Finder desktop layer;
    visibility would depend on intra-layer ordering (Finder may reorder above)
    → fragile. REJECTED.
  - C) `kCGDesktopIconWindowLevel + 1` (-3602): strictly above Finder desktop +
    wallpaper, below normal windows → CHOSEN.
- **Layering verified (layer values are authoritative; CGWindowList *index* order
  is NOT a reliable z-order):**
  - widget -3602 > Finder desktop -3603 ✓  |  widget -3602 > wallpaper -3624 ✓
  - widget -3602 < normal windows (0) ✓ (TextEdit at layer 0 covers it)
- **collectionBehavior:** `[.stationary, .canJoinAllSpaces, .ignoresCycle]`.
  `.canJoinAllSpaces` → visible on every Space (like desktop icons).
  `.ignoresCycle` → never grabbed by Cmd-Tab / window cycling.
  `.stationary` → stays put when switching Spaces. `.fullScreenAuxiliary` NOT
  added: the widget must stay BELOW fullscreen apps, never floating over them.
  Behaviour verified at launch (window shown, covered by normal windows);
  cross-Space look is pending a manual visual check.
- **Consequences / trade-offs:** shares layer -3602 with the Window Server
  menu-bar strip and Notification Center widgets; our widget sits center-screen
  and does not overlap them. The "+1 above kCGDesktopIconWindowLevel" offset is
  the minimal, principled offset. `MP_WINDOW_LEVEL` env var (int raw value)
  overrides the level for future A/B testing; default is the final value above.

---

## D-007: Concurrency separation for sampling vs UI

- **Decision:** Sampling/elaboration (Mach/IOKit) happen off the main thread;
  results published on `@MainActor`. SwiftUI never blocks on metric reads.
- **Motivation:** IOKit/Mach reads must not freeze the UI if slow.
- **Alternatives considered:** sampling on main thread with timer.
- **Why rejected:** risk of UI stall.
- **Consequences / trade-offs:** Slight complexity; safe UI.

---

## D-008: Swift current toolchain / language mode (not forced to Swift 5)

- **Decision:** Use the installed Swift toolchain (6.1.2) and current language
  mode. Handle Swift 6 concurrency properly rather than retrograde to Swift 5.
- **Motivation:** New project; no technical reason to force Swift 5.
- **Consequences / trade-offs:** Must satisfy Swift 6 strict concurrency (Sendable,
  @MainActor) as errors arise.
```

