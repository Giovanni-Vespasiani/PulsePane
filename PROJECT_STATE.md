# PROJECT_STATE.md — MacPerformance v2.0 (operational checkpoint)

> This file is the primary operational checkpoint. Read it first after any
> context compaction or before resuming work. Update after every milestone.

## Current Status
- **V2 CHECKPOINT** — v2 implementation COMPLETE and running. Waiting at
  **VISUAL CHECKPOINT** for the user's eye (terminal has no screen access).
- Visual reference (recorded so it is not lost):
  `~/Documents/screenshot/Screenshot 2026-09-05 alle 21.00.47.png`
  (NOTE: this model cannot view images; v2 is driven by spec + pixel-probe data.
  Final visual judgement = user's eye at the VISUAL CHECKPOINT.)
- **Current V2 state (all verified programmatically):**
  - Window: 340×395 pt, desktop-icon+1 level (-2147483602), on-screen, running.
  - CPU/GPU/MEM regression OK. NET/DISK/PWR all live & responsive to load.
  - TMP + CPU frequency: `nil` → `—` / "M4" (per DECISIONS D-011 / D-009).
  - Overhead (release): ~78 MB RSS, ~0.6% CPU at 1 s sampling.
  - Next: user visual review → spacing/color/layout refinements → commit v2.0.
- **Completed (v1 baseline):** CPU/GPU/RAM real, desktop window at level
  kCGDesktopIconWindowLevel+1 (-2147483602), position persistence, LSUIElement,
  SPM build, docs, git.
- **Completed (v2):** NetworkReader (getifaddrs delta), DiskReader
  (IOBlockStorageDriver delta), PowerReader (AppleSmartBattery SystemLoad),
  TemperatureReader (documented nil), GPU-name label, MiniHistogram +
  MetricHistogramRow + MetricProgressRow + SecondaryMetricRow, full redesigned
  PerformanceWidgetView, versioned frame persistence (D-014), docs updated.
- **GitHub:** Personal private remote configured ✓ — `origin` →
  `git@github-personal:Giovanni-Vespasiani/MacPerformance.git` (private repo,
  SSH authenticated as Giovanni-Vespasiani).

## Environment
- Xcode: 26.6 (Build 17F113) at `/Applications/Xcode.app` (full install, ACTIVE)
- Swift: 6.3.3 (swift-driver 1.148.6), target arm64-apple-macosx26.0
  (NOTE: full-Xcode toolchain; CLT previously reported 6.1.2)
- macOS: 26.6.2 (Build 25G83)
- Architecture: Apple Silicon — Apple M4, 10 logical CPUs (4P + 6E), 16 GB
  unified (LPDDR5). MacBook Air Mac16,13.
- Developer directory (CURRENT, FIXED): `/Applications/Xcode.app/Contents/Developer`
- SDK resolved: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk`
- logicalcpu: 10; hw.memsize: 17179869184 (16 GB)

## Build
- Build command: `scripts/build.sh` (swift build + make-app.sh); or
  `swift build -c debug` + `./scripts/make-app.sh debug`
- Last result: **SUCCESS (release v2)** — window 340×395 at level -2147483602,
  launched and verified running.
  (Screenshot unavailable: terminal lacks screen-recording permission.)
- Path of .app: `~/.build/release/MacPerformance.app`
- Warnings/errors: none

## Metrics

### CPU
- Implementation: DONE — Mach `host_processor_info` (PROCESSOR_CPU_LOAD_INFO),
  tick deltas across user/system/nice/idle (CPUReader.swift).
- Status: WORKING (verified).
- Validation performed: controlled load with N=`sysctl hw.logicalcpu` (10) `yes`
  processes → CPU went idle 0–15% → ~99–100% under load → back to ~12% after kill.
  All test `yes` processes terminated afterwards.
- Known issues: none.

### RAM
- Implementation: DONE — `host_statistics64` vm_statistics64 (MemoryReader.swift).
- Formula used: **used = active + wired + compressed** pages × kernel page size;
  total via `hw.memsize`. Excludes inactive/speculative/free. (Documented in
  code + DECISIONS D-003.)
- Validation performed: idle read 9.3–9.4 GB / 16 GB (58–59%), coherent with
  the earlier vm_stat hand-computation (~9.8 GB). Used as design check, not a
  byte-for-byte Activity Monitor replica.
- Known issues: none.

### GPU
- Implementation: DONE (GPUReader.swift reads `PerformanceStatistics` from
  `IOAccelerator` via public IORegistryEntryCreateCFProperty).
- **Empirical verification under load: DONE (Milestone C passed).**
- IORegistry service: 1× IOAccelerator; class `AGXAcceleratorG16G`;
  CFBundleIdentifier `com.apple.AGXG16G`; IONameMatched `gpu,t8132`.
- Properties found (PerformanceStatistics): `Device Utilization %`,
  `Renderer Utilization %`, `Tiler Utilization %`.
- Counter chosen: `Device Utilization %` (fallbacks Renderer % → Tiler %).
- Test performed (2026-09-05): temporary Metal compute stress (2^22 grid,
  ~300 iters/thread, tight loop, 8 s). Observed: idle 16–20% → 94–100% under
  load → back to ~18% after workload ended. Artifacts removed afterwards.
- Result: VERIFIED / WORKING on this M4.
- Stability/limitations: driver-provided keys ("Device Utilization %" etc.) are
  NOT a documented stable Apple API; isolated in GPUReader.swift. May change on
  other hardware/macOS.

### Network (v2)
- Implementation: DONE — NetworkReader.swift: `getifaddrs`, sums AF_LINK
  interface counters (IFF_UP, excludes `lo`/`awdl`/`llw`/`utun`/`ipsec`/`gif`/
  `stf`), 1 s delta → upload/download bytes/s.
- Validation: idle ~0 B/s; curl download → `↓ 253 KB/s`; `dd` write → `↑`
  responds. VERIFIED.

### Disk (v2)
- Implementation: DONE — DiskReader.swift: IOKit `IOBlockStorageDriver`
  `Statistics` (physical level only: requires `Total Time (Write)` marker to
  avoid APFS double-count), 1 s delta → read/write bytes/s.
- Validation: idle ~0 B/s; `dd if=/dev/zero of=/tmp/ddtest.bin bs=1m count=200`
  → `W 196.4 MB/s`. VERIFIED.

### Power (v2)
- Implementation: DONE — PowerReader.swift: `AppleSmartBattery` →
  `PowerTelemetryData` → `SystemLoad` (mW) /1000 → watts, `nil` on error.
- Validation: idle ≈5.9 W; 10×`yes` ≈8.6 W (telemetry, may lag). Later runs on
  warm system read steady ~8.4 W — reflects system state. VERIFIED (returns live
  SystemLoad).

### Temperature / CPU frequency (v2)
- TemperatureReader.swift: `celsius()` → `nil` (documented; DECISIONS D-011).
- CPU freq: `nil` (DECISIONS D-009). UI shows `—` and "M4". EXPECTED, not a bug.

## Window
- **Level (FINAL): `kCGDesktopIconWindowLevel + 1` = -2147483602.**
  BEFORE the fix: `kCGDesktopWindowLevel` (-2147483623) — widget invisible,
  hidden under Finder's full-screen desktop window (-3603). AFTER: strictly
  above Finder desktop & wallpaper; below normal windows. See DECISIONS D-006.
- Candidate levels tested (env `MP_WINDOW_LEVEL`) and outcome:
  - -2147483623 kCGDesktopWindowLevel → below Finder desktop → hidden (REJECTED)
  - -2147483603 kCGDesktopIconWindowLevel → same layer as Finder, fragile (REJECTED)
  - -2147483602 kCGDesktopIconWindowLevel + 1 → above Finder desktop (CHOSEN)
- **Size (v2): 340×395 pt** (content-defined; width fixed 340).
- Frameless: styleMask [.borderless] → no title bar / traffic lights. ✓
- Normal windows in front: layer 0 > widget -3602; verified with TextEdit. ✓
- Drag: `isMovableByWindowBackground = true` (standard AppKit; not verified
  interactively — terminal lacks accessibility for synthetic drag).
- Persistence: **versioned** `MacPerformance.windowFrame = "v2|<NSStringFromRect>"`
  (DECISIONS D-014); origin reused on restore, size always v2 default. ✓
- Off-screen clamp: saved off-screen rect → reset to default centered frame. ✓
- Hidden from Dock: Info.plist LSUIElement=1 (no Dock icon). ✓
- Quit: right-click context menu "Quit MacPerformance". Also `pkill -x MacPerformance`.
- collectionBehavior: [.stationary, .canJoinAllSpaces, .ignoresCycle];
  .fullScreenAuxiliary deliberately NOT set (must stay under fullscreen apps).
- Ordering call: `orderFrontRegardless()` in `show()`.
- Debug: `MP_DEBUG=1` prints level rawValue, frame, isVisible, occlusionState,
  screen AND every metric (`NET`/`DISK`/`PWR`/`TMP`);
  `MP_WINDOW_LEVEL=<raw int>` overrides level (default = final value).

## UI (v2)
- Design status: IMPLEMENTED (build 5b0b0d4..; running on desktop) — awaiting
  user's VISUAL CHECKPOINT.
- Dimensions: 340×395 pt (spec ~320–345×400–450 — close; adjustable).
- Elements: header "MacPerformance" + subtitle + M4 capsule badge; CPU row
  (label, sub-label, 22-bar MiniHistogram, %); GPU row (same, "Apple GPU"
  sub-label); Memory row (label, GB text, %, full-width thin progress bar);
  divider; Network ↑/↓ row; Disk R/W row; Power+Temp row.
- Colors: CPU calm blue, GPU muted violet, monospaced digits, darkAqua forced
  material over dark-blue tint, corner radius 28, subtle 0.5pt border.
- To refine: everything visual (pending user's eye).

## Next Actions
1. [DONE] v2 checkpoint + WindowController fixes (D-014)
2. [DONE] v2 readers (Network/Disk/Power/Temperature) + sampler wiring
3. [DONE] v2 UI components + full panel redesign
4. [DONE] Tests: CPU/GPU/RAM regression, NET/DISK/PWR load response, TMP nil
5. [DONE] Overhead measured (78 MB RSS / 0.6% CPU release)
6. [DONE] Docs updated (README/ARCHITECTURE/DECISIONS/DEVELOPMENT/PROJECT_STATE)
7. **User VISUAL CHECKPOINT** — look at the widget; give feedback (spacing,
   colors, shapes, layout).
8. Adjust per feedback; final commit of v2.0.

## Important Commands
- Build: `swift build -c release`
- Run app: `open ~/.build/release/MacPerformance.app`
- Debug log: (TBD)
- CPU test: `nproc`-equivalent via `sysctl hw.logicalcpu`; spawn/terminate `yes` tasks
- GPU test: throwaway Metal workload (in `scripts/`), then remove
- Cleanup: `swift package clean`

## Known Issues
- Screen capture unavailable in this shell (no screen-recording permission) —
  UI verified only via process, window enumeration + debug logs. Final visual
  confirmation ("widget visible over desktop, layout looks right", Spaces/
  Mission Control/show-desktop, drag) is the user's manual step.
- Overhead measured v2 release: ~78 MB RSS, ~0.6% CPU (v1 was ~74 MB / ~1.9%).
- Temperature (SoC) and CPU frequency intentionally nil (DECISIONS D-011/D-009) —
  UI shows `—` / "M4". Not bugs.

## Last Verified
- v2 widget 340×395 pt at level -2147483602, on-screen (CGWindowList), running. ✓
- CPU load test (10×`yes`): idle→~99.7%→idle. ✓
- RAM idle: ~9.3 GB/16 GB (58%). ✓
- GPU idle (no load): 10–21%; under Metal load 94–100% (Milestone C). ✓
- NET: curl download → `↓ 253 KB/s`; idle ~0. ✓
- DISK: `dd` write → `W 196.4 MB/s`; idle ~0. ✓
- PWR: idle ≈5.9 W; under load ≈8.6–8.4 W (telemetry, may lag). ✓
- TMP: `—` expected (nil). CPU freq: "M4" sub-label expected (nil). ✓
