# PROJECT_STATE.md — MacPerformance v0.1 (operational checkpoint)

> This file is the primary operational checkpoint. Read it first after any
> context compaction or before resuming work. Update after every milestone.

## Current Status
- **Milestone:** D (desktop window behaviour) — COMPLETE (programmatically verified).
- **Completed:** A–D. Widget window: frameless, level kCGDesktopWindowLevel,
  normal windows in front, position restore + off-screen clamp, LSUIElement.
- **Partially completed:** Design polish; visual confirmation of Spaces /
  Mission Control / show-desktop pending (no screen access in this shell).
- **Not started:** E (design), F (sparklines), G (overhead/final docs).

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
- Last result: SUCCESS (debug). App launched and verified as running process.
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
- Level used: `kCGDesktopWindowLevel` (-2147483623), via
  `CGWindowLevelForKey(.desktopWindow)`. AppKit `.desktop` constant is NOT
  available in macOS 26 SDK → use CoreGraphics level directly.
- Frameless: styleMask [.borderless] → no title bar / traffic lights. ✓
- Normal windows in front: verified with TextEdit — TextEdit (layer 0) above
  widget (layer -2147483623). ✓
- Draggable: `isMovableByWindowBackground = true` (standard AppKit; not
  verified interactively — terminal lacks accessibility for synthetic drag).
- Persistence: frame saved to UserDefaults `MacPerformance.windowFrame`
  (NSStringFromRect) on windowDidMove; restored on launch. Verified: saved
  {{120,640},…} → restored X=120 (Y consistent, CG vs AppKit coords). ✓
- Off-screen clamp: saved {9000,9000} → reset to default centered frame. ✓
- Hidden from Dock: Info.plist LSUIElement=1 (no Dock icon). ✓
- Quit: right-click context menu "Quit MacPerformance" (no Dock, so no menu bar
  item). Not interactively tested (accessibility). Also `pkill -x MacPerformance`.
- Spaces: collectionBehavior [.stationary]; desktop-level → behaves like
  desktop icons. **Visual confirmation of Spaces change / Mission Control /
  show-desktop still pending (manual).**
- Open problems: none known; visual checks outstanding.

## UI
- Design status: NOT STARTED (Milestone E).
- Dimensions (target): ~300–340 wide × 170–220 high (medium widget).
- Elements: planned — header, CPU/GPU/MEMORY rows, thin bars.
- To refine: everything (pending)

## Next Actions
1. [MILESTONE D] NSWindow desktop behaviour (frameless, drag, persist, level,
   Spaces/Mission Control tests).
2. [MILESTONE E] Widget design polish.
3. [MILESTONE F] Sparklines CPU/GPU (30s history).
4. [MILESTONE G] Overhead test + final docs + git commits.

## Important Commands
- Build: `swift build -c release`
- Run app: `open ~/.build/release/MacPerformance.app`
- Debug log: (TBD)
- CPU test: `nproc`-equivalent via `sysctl hw.logicalcpu`; spawn/terminate `yes` tasks
- GPU test: throwaway Metal workload (in `scripts/`), then remove
- Cleanup: `swift package clean`

## Known Issues
- GPU not yet verified under controlled load (next: Metal workload test).
- Screen capture unavailable in this shell (no screen-recording permission) —
  UI verified only via process + debug logs so far.

## Last Verified
- CPU load test (10×`yes`): idle→~100%→idle. ✓
- RAM idle: ~9.3 GB/16 GB (58%). ✓
- GPU idle (no load): 10–21%.
