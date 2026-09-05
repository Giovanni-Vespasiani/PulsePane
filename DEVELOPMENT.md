# DEVELOPMENT.md — MacPerformance v0.1

Technical notes for developing and continuing this project.

## Environment
- Xcode: 26.6 (Build 17F113), installed at `/Applications/Xcode.app`
- Swift: 6.1.2 (swift-driver 1.120.5), target arm64-apple-macosx16.0
- macOS: 26.6.2 (Build 25G83)
- Hardware: Apple M4 — 10 cores (4 Performance + 6 Efficiency), 16 GB unified
  memory (LPDDR5). MacBook Air Mac16,13.
- Architecture: arm64 (Apple Silicon).

## Developer directory
Must point at the full Xcode, not CommandLineTools, for `xcodebuild`:
```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
Verify:
```
xcode-select -p            # → /Applications/Xcode.app/Contents/Developer
xcodebuild -version        # → Xcode 26.6 ...
swift --version
```

## SDK
Do not hardcode. Resolve the installed SDK:
```
xcrun --show-sdk-path --sdk macosx
```
Xcode 26 ships MacOSX26.5.sdk and MacOSX26.sdk.

## Build
Swift Package Manager + bundle assembly script (see DECISIONS D-001).
```
scripts/build.sh
```
This runs `swift build -c release` and assembles:
```
MacPerformance.app/
  Contents/
    Info.plist
    MacOS/MacPerformance
    Resources/
```
SPM does not emit a `.app`; `scripts/make-app.sh` does the assembly.

## Run
```
scripts/run.sh
# or:
open ~/.build/release/MacPerformance.app
```

## Debugging
- Logs to stderr/os_log.
- For GPU/property inspection:
  ```
  ioreg -l -w0 -r -c IOAccelerator
  ```
- For memory counters:
  ```
  vm_stat
  memory_pressure
  sysctl hw.memsize hw.logicalcpu
  ```

## Tests: CPU / RAM / GPU

### CPU
Get real logical CPU count (do NOT hardcode 10):
```
sysctl hw.logicalcpu
```
Generate controlled workload with that many parallel `yes` tasks, observe
idle → load → heavier load → idle, then **kill all** created tasks:
```
N=$(sysctl -n hw.logicalcpu)
for i in $(seq 1 $N); do yes > /dev/null & done
# observe ...
pkill -x yes   # or kill the specific PIDs created
```
Note: macOS global CPU often saturates below 100% in the UI due to efficiency
core accounting; the validation is correct response to load, not hitting 100%.

### RAM
Cross-check our "used = active + wired + compressed" against `vm_stat` /
`memory_pressure` / Activity Monitor (sanity check only, not byte-for-byte).

### GPU
No scrolling/animation as proof. Build a small throwaway Metal workload, verify:
idle → low value; workload → significantly higher; end → returns down. Then
remove/terminate all temporary artifacts.

Verified approach used in Milestone C (recorded for future re-runs):
- A temporary Metal compute stress (kernel: per-thread sin/sqrt/cos loop, grid
  2^22 threads, ~300 iterations, dispatched in a tight loop) compiled as a CLI
  with `swiftc -framework Metal -framework Foundation` and run for ~8 s.
- Result on this M4 with `Device Utilization %`: idle 16–20% → 94–100% under
  load → back to ~18% after stop. Workload and binary removed after the test.

## Notes for continuing development
- Keep sampling off the main thread; publish results on `@MainActor`.
- GPUReader is designed to be replaceable if a better API is found later.
- Update PROJECT_STATE.md after every milestone before any possible context
  compaction.
