# PROJECT_STATE.md — MacPerformance v0.1 (operational checkpoint)

> This file is the primary operational checkpoint. Read it first after any
> context compaction or before resuming work. Update after every milestone.

## Current Status
- **Milestone:** A (environment + project scaffold + first compilable .app) — COMPLETE.
- **Completed:** Environment fixed (full Xcode active); project at
  ~/Projects/MacPerformance; git initialized; initial docs; SPM package;
  build/run scripts; first **compilable & launchable** MacPerformance.app
  (debug), verified running as a process.
- **Partially completed:** Native window/desktop behaviour pending (Milestone D).
- **Not started:** B (CPU/RAM in code), C (GPU), D (window), E (design), F (sparklines),
  G (overhead/final docs).

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
