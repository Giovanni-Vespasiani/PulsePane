# PROJECT_STATE.md — MacPerformance v0.1 (operational checkpoint)

> This file is the primary operational checkpoint. Read it first after any
> context compaction or before resuming work. Update after every milestone.

## Current Status
- **Milestone:** A (environment + project scaffold) — in progress.
- **Completed:** Project directory created at `~/Projects/MacPerformance`; git
  initialized; initial documentation files created; source layout scaffolded.
- **Partially completed:** Xcode CLI is broken (needs `sudo xcode-select -s`).
- **Not started:** B (CPU/RAM), C (GPU), D (window), E (design), F (sparklines),
  G (overhead/final).

## Environment
- Xcode: 26.6 (Build 17F113) at `/Applications/Xcode.app` (full install present)
- Swift: 6.1.2 (swift-driver 1.120.5), target arm64-apple-macosx16.0
- macOS: 26.6.2 (Build 25G83)
- Architecture: Apple Silicon — Apple M4, 10 cores (4P + 6E), 16 GB unified
  (LPDDR5). MacBook Air Mac16,13.
- Developer directory (current, BROKEN): `/Library/Developer/CommandLineTools`
- Required fix: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- SDK detected: Xcode ships MacOSX26.5.sdk + MacOSX26.sdk (use `xcrun --show-sdk-path`)

## Build
- Build command: `swift build -c release` then `scripts/make-app.sh` (or `scripts/build.sh`)
- Last result: NOT YET BUILT (blocked on sudo fix for full Xcode CLI)
- Path of .app: `~/.build/release/MacPerformance.app` (after script) — pending
- Warnings/errors: none yet (no build yet)

## Metrics

### CPU
- Implementation: NOT STARTED. Planned: Mach `host_processor_info`
  (PROCESSOR_CPU_LOAD_INFO), tick deltas (user/system/nice/idle).
- Status: pending
- Validation performed: none yet
- Known issues: none yet

### RAM
- Implementation: NOT STARTED. Planned: `host_statistics64` vm_statistics64.
- Formula to use: **used = active + wired + compressed** (excludes inactive/speculative/free).
- Validation performed: idle computation done via `vm_stat` page size 16384:
  active=357492, wired=132110, compressor occupied=150842 → approx 9.8 GB / 16 GB (~61%).
- Known issues: none yet

### GPU
- IORegistry service found: exactly one `IOAccelerator`-class service.
- GPU class: `AGXAcceleratorG16G` (`MetalPluginName` = `AGXMetalG16G_B0`,
  `IONameMatched` = `gpu,t8132`, `CFBundleIdentifier` = `com.apple.AGXG16G`).
- Properties found (in `PerformanceStatistics`): `Device Utilization %`,
  `Renderer Utilization %`, `Tiler Utilization %`, plus memory/split counters.
  Also `AGCInfo` (submission/busy counters). Values observed fluctuating over time
  (8→12→11→9) — evidence of liveness, NOT yet proof of tracking under load.
- Counter chosen: TBD (priority: Device Utilization %, fallback Renderer/Tiler).
- Tests performed: IORegistry enumeration + idle sampling only. **No load test yet.**
- Result: NOT verified under load yet. Treat as UNVERIFIED until Milestone C.
- Fallback: Renderer % / Tiler %; if none reliable → declare PARTIAL/UNKNOWN explicitly.
- Stability/limitations: driver-dependent keys; not a documented stable Apple API.

## Window
- Level used: NOT SET yet (Milestone D). Planned empirical determination.
- Finder behaviour: N/A
- Normal windows in front: N/A
- Spaces: N/A
- Mission Control: N/A
- Drag: N/A
- Persistence: N/A
- Open problems: none yet

## UI
- Design status: NOT STARTED (Milestone E).
- Dimensions (target): ~300–340 wide × 170–220 high (medium widget).
- Elements: planned — header, CPU/GPU/MEMORY rows, thin bars.
- To refine: everything (pending)

## Next Actions
1. [BLOCKED] Run sudo command to fix Xcode CLI (single command, provided to user).
2. Verify `xcode-select -p`, `xcodebuild -version`, `swift --version`.
3. Create `Package.swift` + minimal app sources; build first compilable `.app`.
4. Implement CPUReader + MemoryReader + SystemMonitor (1s); verify values.
5. GPU controlled Metal load test → finalize GPUReader.
6. Window behaviour (Milestone D).
7. Design (Milestone E).
8. Sparklines (Milestone F).
9. Overhead test + final docs + git commits (Milestone G).

## Important Commands
- Build: `swift build -c release`
- Run app: `open ~/.build/release/MacPerformance.app`
- Debug log: (TBD)
- CPU test: `nproc`-equivalent via `sysctl hw.logicalcpu`; spawn/terminate `yes` tasks
- GPU test: throwaway Metal workload (in `scripts/`), then remove
- Cleanup: `swift package clean`

## Known Issues
- Xcode CLI broken until sudo `xcode-select -s` is executed.
- GPU not yet verified under load.

## Last Verified
- 2026-09-05 (session start): environment values above; GPU PerformanceStatistics
  keys present and fluctuating; vm_stat memory counters sampled.
