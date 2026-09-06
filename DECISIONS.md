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

---

## D-009: CPU frequency is not shown — no reliable non-privileged API (v2)

- **Decision:** `cpuFrequencyGHz` is `nil`; the UI shows `—`.
- **Motivation (investigated 2026-09-05, Apple M4 / macOS 26.6.2):** there is **no
  non-privileged API** for the *current live* CPU frequency. `hw.cpufrequency`/
  `hw.cpufrequency_max`/`min` report nothing on Apple Silicon; `pmset -g
  therm`/`processor_usage` need root; Apple Silicon exposes no public
  "boost/clockspeed" knob. Fabricated/per-core guesses would violate the
  honesty rule.
- **Alternatives considered:** reading `hw.cpufrequency*`, `sysctl machdep`, the
  private `IOReport` CPU frequency channels.
- **Why rejected:** unavailable without privileges / private API.
- **Consequences / trade-offs:** shows "M4" as the CPU sub-label instead of a
  frequency. If a public API appears, this is a one-line change in MetricSampler.

---

## D-010: Power (watts) from AppleSmartBattery PowerTelemetryData.SystemLoad (v2)

- **Decision:** `powerWatts = SystemLoad / 1000` read from IOKit service
  `AppleSmartBattery` → `PowerTelemetryData` → `SystemLoad`, then divided by 1000
  on the assumption the value is milliwatts.
- **Motivation:** live, real, non-privileged system power estimate from Apple's
  own telemetry. Validated on this M4: idle ≈ 5894 (≈5.9 W), under 10×`yes`
  ≈ 8617 (≈8.6 W) — magnitude and delta-to-load both plausible for this MacBook
  Air.
- **Unit reasoning:** the raw magnitude (thousands, ~5–9 W typical) is consistent
  with milliwatts and incoherent with any other unit. Cross-validated against the
  boot-time `AccumulatedSystemLoad / SystemLoadAccumulatorCount` average.
- **Alternatives considered:** `ioreg` subprocess (rejected: subprocess per tick
  banned), energy graph via private APIs (rejected).
- **Consequences / trade-offs:** it is Apple's telemetry estimate, not a lab
  power meter; label it as an estimate. Reader isolated in PowerReader.

---

## D-011: SoC temperature is nil — no clean non-privileged API found (v2)

- **Decision:** `socTemperatureCelsius = nil`; UI shows `—`. The reader exists
  (TemperatureReader) as the single place where a future clean API would go.
- **Motivation (investigated 2026-09-05, Apple M4 / macOS 26.6.2):**
  - `AppleSmartBattery` → `Temperature` (≈3069 deci-K ≈ 33.7 °C) is a *battery*
    temperature, not the SoC — we refuse to mislabel it.
  - `AppleEmbeddedNVMeTemperatureSensor` is NVMe-controller temp, not SoC.
  - `IOReport` `MSP0`/`MSP1` `"Temperature(0)"` channels exist but are only
    reachable via the private `/usr/lib/libIOReport` dylib (no Swift module),
    with unknown units (unit code 0) — too fragile to trust.
- **Why rejected:** mislabeling battery/NVMe as SoC, or using a private dylib
  with unverifiable units, both violate the honesty rule.
- **Consequences / trade-offs:** no temperature shown in v2. Single-file change
  when a public API appears.

---

## D-012: GPU label is a friendly static name (v2)

- **Decision:** the GPU sub-label shows `"Apple GPU"` (from `gpuName`), not the
  technical service string `AGXAcceleratorG16G`.
- **Motivation:** an Apple-like widget must not print internal kernel/registry
  device strings; `Apple GPU` is the user-facing manufacturer name for Apple
  Silicon and stable.
- **Alternatives considered:** showing the IOKit service class name.
- **Why rejected:** technical, unfriendly, and it is an empirical driver string.
- **Consequences / trade-offs:** we do not distinguish the exact GPU variant. If
  desired later, a hardware-family table keyed off registry properties could map
  to "M4" etc.

---

## D-013: v2 histograms are bars, sampled at 1 s, 22 samples (v2)

- **Decision:** CPU/GPU history renders as a **MiniHistogram** of 22 thin bars
  (replacing the v0.1 sparkline) at the existing 1 s sampling rate.
- **Motivation:** match the reference visual style; a bar histogram reads as a
  "live oscilloscope" better than a hairline sparkline at small sizes; preserves
  the v0.1 energy budget (same 1 Hz sample rate, no new cost).
- **Alternatives considered:** sparkline kept; smooth line-graph; WidgetKit.
- **Why rejected:** WidgetKit cannot update at 1 Hz (D-005). The hairline
  sparkline was replaced by bars to match the reference look.
- **Consequences / trade-offs:** 22-sample history (~22 s). Bars are discrete by
  design; no anti-aliased line smoothing.

---

## D-014: Window frame persistence is versioned; size always the v2 default (v2)

- **Decision:** the persisted frame becomes `"v2|<NSStringFromRect>"`. On
  restore, the **origin** is reused (if it is still on a visible screen) but the
  **size is always reset** to the v2 default. Unknown/old (`v1`) pref → centered
  default.
- **Motivation:** a stale v1 frame (320×~260 layout) would shrink/misalign the
  taller v2 panel; versioning cleanly arms one-migration without a data model.
- **Alternatives considered:** ignoring saved location entirely; tracking frame
  origin only.
- **Why rejected:** ignoring origin loses the user's placement; origin-only is
  the same thing — versioned string is the minimal explicit migration.
- **Consequences / trade-offs:** first v2 launch is centered; from then on the
  drag position is preserved. Future layout changes only bump the version tag.

---

## D-R001: Retain legacy bundle identifier for v2.1 to preserve UserDefaults

- **Decision:** Keep `CFBundleIdentifier = local.MacPerformance` in v2.1
  (rebrand prep) so existing users' window position persists automatically.
- **Motivation:** Changing the bundle identifier would move preferences to a new
  domain, resetting window position and any future persisted state.
- **Alternatives considered:** Change bundle ID immediately with migration code
  in v2.1.
- **Why rejected:** Adds complexity to v2.1; migration can be done cleanly in
  v2.2+ when professional bundle ID is adopted. Zero user disruption now.
- **Consequences / trade-offs:** Temporary "local." prefix remains; professional
  identifier deferred to v2.2.

---

## D-R002: UserDefaults migration strategy — legacy domain import on first launch

- **Decision:** When bundle identifier eventually changes (v2.2+), migrate
  `MacPerformance.windowFrame` → `<NewName>.windowFrame` on first launch if
  new key absent.
- **Motivation:** Seamless continuity — users never lose window position.
- **Implementation:** One-time check in `WindowController.init` or App delegate.
- **Consequences / trade-offs:** Simple, robust, no orphaned preferences.

---

## D-R003: Future bundle identifier pattern

- **Decision:** `io.github.Giovanni-Vespasiani.<kebab-case-new-name>`
- **Motivation:** Reverse-DNS with owned GitHub namespace — stable, unique,
  compatible with Apple signing/notarization and Homebrew.
- **Examples:** `io.github.Giovanni-Vespasiani.silhouette`,
  `io.github.Giovanni-Vespasiani.vitals`, etc.
- **Consequences / trade-offs:** Professional, standard, future-proof.

---

## D-R004: Source rename scope — only public-facing identifiers

- **Decision:** Rename only: SPM package/product/target, executable, app bundle,
  CFBundleDisplayName/Name/Identifier, App struct, window title, quit menu,
  frame key, UI header text, GitHub repo. Keep all generic internal types
  (`PerformanceWidgetView`, `SystemMonitor`, `MetricSampler`, `*Reader`, etc.).
- **Motivation:** Avoid massive noisy diffs for zero user value.
- **Consequences / trade-offs:** Internal code still references "MacPerformance"
  in type names; acceptable for implementation details.

---

## D-R005: GitHub repository rename procedure

- **Decision:** Rename via GitHub web UI → update local `origin` remote URL →
  verify fetch. Preserves history, tags, issues.
- **Commands:** `git remote set-url origin git@github-personal:Giovanni-Vespasiani/<new-name>.git`
- **Consequences / trade-offs:** Zero history loss; existing clones need one
  `git remote set-url`.

---

## D-R006: Versioning policy from v2.0 freeze onward

- **Decision:**
  - v2.0.0 — stable pre-rebrand (TAGGED)
  - v2.1.0 — completed rebrand / public identity
  - v2.2.0 — hardening
  - v2.3.0 — tests + CI
  - v2.4.0 — public-readiness (license, docs, signing)
- **Consequences / trade-offs:** Clear milestones; rebrand isolated in v2.1.

---

## D-R007: Final brand name = PulsePane

- **Decision:** The final product name is **PulsePane**.
- **Motivation:** Short, memorable, combines "pulse" (live heartbeat/1 Hz refresh) with "pane" (desktop panel/widget). Professional, Apple-like, suitable for macOS desktop utility.
- **Alternatives considered:** Silhouette, Vitals, Pulse, Glance, Prism (top 5 shortlist).
- **Why chosen:** Strongest overall brandability (combines live monitoring metaphor with desktop pane concept); clean bundle ID (`io.github.Giovanni-Vespasiani.pulsepane`); available GitHub repo name with minor qualifier; extensible for future Apple Silicon/AI metrics.
- **Consequences / trade-offs:** "Pulse" alone has heavy collisions; "Pane" suffix differentiates and reinforces desktop widget positioning.

---

## D-H001: SafeDelta utility centralizes counter delta logic

- **Decision:** Introduce `SafeDelta` enum and `DeltaCounter` class in `Sources/PulsePane/Monitoring/SafeDelta.swift`. All delta-based readers (CPU, Network, Disk) use this shared utility.
- **Motivation:** Eliminate duplicated reset/wraparound logic across CPU, Network, and Disk readers. Centralize behavior for: first sample (nil), counter reset/wraparound (nil), zero elapsed (nil), valid delta (rate).
- **Alternatives considered:** Keep duplicated logic in each reader; create a protocol with default implementation.
- **Why rejected:** Duplication increases bug surface; protocol adds complexity without benefit.
- **Consequences / trade-offs:** Single source of truth for delta logic; easier to audit and test.

---

## D-H002: GPUReader service caching with wake invalidation

- **Decision:** GPUReader caches the discovered `IOAccelerator` service on first valid read. `invalidate()` clears cache, forcing rediscovery on next sample. WakeHandler calls `resetBaselines()` which calls `invalidate()` on wake.
- **Motivation:** Avoid repeated `IOServiceGetMatchingServices` calls every second. Handle service disappearance after sleep/wake gracefully.
- **Alternatives considered:** Discover every sample; cache forever.
- **Why rejected:** Discovery every sample wastes CPU; forever caching breaks after sleep/wake or driver reload.
- **Consequences / trade-offs:** Slightly more complex state machine; much better performance and resilience.

---

## D-H003: PowerReader semantic honesty and bounds

- **Decision:** Document `PowerTelemetryData.SystemLoad` as "reported system load power" (Apple telemetry estimate), not "total system power". Enforce plausible bounds [0, 500] W. Return `nil` on missing service/key, malformed value, or out-of-bounds.
- **Motivation:** The exact meaning of `SystemLoad` is not officially documented by Apple. Empirical validation suggests milliwatts, but we must not claim certainty.
- **Alternatives considered:** Label as "total system power"; omit bounds checking.
- **Why rejected:** Misrepresents Apple telemetry; missing bounds allows absurd values to reach UI.
- **Consequences / trade-offs:** UI shows `—` on desktop Macs (no battery) — honest but less useful.

---

## D-H004: NetworkReader interface exclusion policy

- **Decision:** Exclude virtual/tunnel interfaces by prefix: `lo`, `awdl`, `llw`, `utun`, `ipsec`, `gif`, `stf`. Only include IFF_UP, AF_LINK interfaces.
- **Motivation:** Virtual interfaces (VPN, AWDL, tunnels) produce high-variance counters that distort "real" network traffic picture.
- **Alternatives considered:** Include all UP interfaces; include only primary interface.
- **Why rejected:** All UP includes VPN/tunnel noise; primary-only misses multi-homed traffic.
- **Consequences / trade-offs:** May miss some legitimate traffic on unusual interfaces; cleaner signal.

---

## D-H005: DiskReader physical driver filter

- **Decision:** Only accept `IOBlockStorageDriver` Statistics dictionaries containing the `Total Time (Write)` marker key (physical driver level). Skip APFS/volume overlays.
- **Motivation:** APFS volumes expose byte counters that double-count the same physical I/O.
- **Alternatives considered:** Sum all Statistics; use `IOMedia` instead.
- **Why rejected:** Summing all double-counts; `IOMedia` doesn't expose byte counters reliably.
- **Consequences / trade-offs:** Only reports physical drive I/O; misses per-volume breakdown.

---

## D-H006: WakeHandler baseline reset for all delta readers

- **Decision:** WakeHandler listens for `NSWorkspace.willSleepNotification`/`didWakeNotification`. On wake, calls `resetBaselines()` on CPU, Network, Disk, and GPU readers.
- **Motivation:** Delta-based counters would compute massive false deltas across the sleep interval (hours of "zero" time).
- **Alternatives considered:** Ignore sleep/wake; timestamp-based compensation.
- **Why rejected:** Ignoring causes massive false spikes; timestamp compensation is complex and error-prone.
- **Consequences / trade-offs:** First sample after wake returns nil (baseline reset); one second of missing data is acceptable.

