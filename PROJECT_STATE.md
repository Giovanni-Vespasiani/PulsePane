# PROJECT_STATE.md — MacPerformance v0.1 (operational checkpoint)

> This file is the primary operational checkpoint. Read it first after any
> context compaction or before resuming work. Update after every milestone.

## Current Status
- **Milestone D (desktop window behaviour): RE-OPENED → FIXED.** The widget was
  NOT visible on the desktop: level `kCGDesktopWindowLevel` (-2147483623)
  sat BELOW Finder's full-screen desktop window (`kCGDesktopIconWindowLevel`) and
  was hidden by it. **Preliminary state documented BEFORE the fix; resolution
  below (AFTER).**
- **CAUSE (precise):** On macOS 26.6 the compositor stack is
  wallpaper (Dock `Wallpaper-…`, -3624) → **Finder desktop window (-3603, full
  screen)** → normal windows (0). The widget at -3623 was therefore below the
  Finder desktop window and invisible, even though it was "on screen" in
  `CGWindowListCopyWindowInfo`.
- **FIX (final):** level = `kCGDesktopIconWindowLevel + 1` = **-2147483602** —
  strictly above Finder desktop & wallpaper, below all normal windows. NOT
  always-on-top.
- **collectionBehavior (final):** `[.stationary, .canJoinAllSpaces, .ignoresCycle]`
  (no `.fullScreenAuxiliary`: widget must stay below fullscreen apps).
- **Verified (programmatically):** widget -3602 > Finder desktop -3603 ✓;
  widget -3602 > wallpaper -3624 ✓; widget < normal windows (0) ✓ (TextEdit at
  layer 0 covers it). Frame on-screen, `isVisible=true`, occlusionState visible,
  screen attached ✓.
- **Debug keys added:** `MP_DEBUG=1` → startup diagnostics (level rawValue, frame,
  isVisible, occlusionState, screen). `MP_WINDOW_LEVEL=<int>` → override level
  for A/B tests (default = final -3602).
- **Remaining (manual, visual):** design look, drag feel, and Spaces ×
  Mission Control × "show desktop" behaviour — no screen access in this shell.

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
- Last result: SUCCESS (debug) — window level FIXED to -2147483602, verified.
  App launched and verified as running process.
  (Screenshot unavailable: terminal lacks screen-recording permission.)
- Path of .app: `~/.build/debug/MacPerformance.app` (and `release` after scripts/build.sh)
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

## Window
- **Level (FINAL): `kCGDesktopIconWindowLevel + 1` = -2147483602.**
  BEFORE the fix: `kCGDesktopWindowLevel` (-2147483623) — widget invisible,
  hidden under Finder's full-screen desktop window (-3603). AFTER: strictly
  above Finder desktop & wallpaper; below normal windows. See DECISIONS D-006.
- Candidate levels tested (env `MP_WINDOW_LEVEL`) and outcome:
  - -2147483623 kCGDesktopWindowLevel → below Finder desktop → hidden (REJECTED)
  - -2147483603 kCGDesktopIconWindowLevel → same layer as Finder, fragile (REJECTED)
  - -2147483602 kCGDesktopIconWindowLevel + 1 → above Finder desktop (CHOSEN)
- Frameless: styleMask [.borderless] → no title bar / traffic lights. ✓
- Normal windows in front: layer 0 > widget -3602; verified with TextEdit. ✓
- Drag: `isMovableByWindowBackground = true` (standard AppKit; not verified
  interactively — terminal lacks accessibility for synthetic drag).
- Persistence: frame saved to UserDefaults `MacPerformance.windowFrame`
  (NSStringFromRect) on windowDidMove; restored on launch. Verified: saved
  {{120,640},…} → restored X=120 (Y consistent, CG vs AppKit coords). ✓
- Off-screen clamp: saved {9000,9000} → reset to default centered frame. ✓
- Hidden from Dock: Info.plist LSUIElement=1 (no Dock icon). ✓
- Quit: right-click context menu "Quit MacPerformance" (no Dock → no menu bar
  item). Not interactively tested (accessibility). Also `pkill -x MacPerformance`.
- collectionBehavior: [.stationary, .canJoinAllSpaces, .ignoresCycle];
  .fullScreenAuxiliary deliberately NOT set (must stay under fullscreen apps).
  Launch-time behaviour verified; cross-Space / Mission Control / show-desktop
  visual confirmation pending (manual).
- Ordering call: `orderFrontRegardless()` in `show()` — shows WITHOUT activating
  (LSUIElement accessory must not steal focus).
- Debug: `MP_DEBUG=1` prints level rawValue, frame, isVisible, occlusionState,
  screen; `MP_WINDOW_LEVEL=<raw int>` overrides level (default = final value).

## UI
- Design status: NOT STARTED (Milestone E).
- Dimensions (target): ~300–340 wide × 170–220 high (medium widget).
- Elements: planned — header, CPU/GPU/MEMORY rows, thin bars.
- To refine: everything (pending)

## Next Actions
1. [DONE/FIXED] NSWindow desktop level fixed (kCGDesktopIconWindowLevel + 1).
2. User visual confirmation: widget visible over desktop, under normal windows,
   drag, Spaces / Mission Control / show-desktop.
3. Any adjustments after feedback; final commit.

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
  confirmation ("widget visible over desktop, under normal windows", Spaces/
  Mission Control/show-desktop, drag) is the user's manual step.
- Overhead numbers (RSS ~74 MB; avg CPU ~1.9%) measured pre-fix; re-measure if
  needed after final user feedback (level change does not affect them).

## Last Verified
- Window layering after fix: widget -3602 above Finder desktop -3603 and
  wallpaper -3624; below normal windows (TextEdit, 0). ✓
- Window on-screen, isVisible, occlusionState visible, screen attached. ✓
- CPU load test (10×`yes`): idle→~100%→idle. ✓
- RAM idle: ~9.3 GB/16 GB (58%). ✓
- GPU idle (no load): 10–21%.
