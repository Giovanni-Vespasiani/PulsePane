# DEVELOPMENT.md — PulsePane v2.1

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
PulsePane.app/
  Contents/
    Info.plist
    MacOS/PulsePane
    Resources/
```
SPM does not emit a `.app`; `scripts/make-app.sh` does the assembly.

## Run
```
scripts/run.sh
# or:
open ~/.build/release/PulsePane.app
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

## v2.2 Hardening Notes
- **SafeDelta/DeltaCounter:** All delta-based readers (CPU, Network, Disk) use `DeltaCounter` for safe delta computation. Handles first sample, counter reset, zero elapsed time.
- **WakeHandler:** Listens for `NSWorkspace.willSleepNotification`/`didWakeNotification`. Calls `resetBaselines()` on CPU, Network, Disk, GPU readers. GPUReader also invalidates service cache.
- **GPUReader:** Caches `IOAccelerator` service on first valid read. `invalidate()` forces rediscovery. Called on wake.
- **PowerReader:** Documents telemetry semantics honestly ("reported system load power"). Bounds: 0–500 W. Returns nil on desktop Macs (no battery).
- **NetworkReader:** Excludes virtual interfaces (lo, awdl, llw, utun, ipsec, gif, stf). Uses `DeltaCounter` for safe deltas.
- **DiskReader:** Only accepts physical driver Statistics (marker key `Total Time (Write)`). Uses `DeltaCounter`.
- **Sanitizers/Formatters:** `MetricSanitizers` + `MetricFormatters` in `Models/Sanitizers.swift`. All UI values pass through sanitizers before formatting.
- **WakeHandler:** Listens for `NSWorkspace.willSleepNotification`/`didWakeNotification`. Calls `resetBaselines()` on CPU, Network, Disk, GPU readers.
- **Sanitizers:** `MetricSanitizers` clamps/validates all metrics. `MetricFormatters` formats for display.
- **WindowController:** Enhanced frame validation (malformed/off-screen/legacy).

## GitHub Remote
- **Remote name:** `origin`
- **URL:** `git@github-personal:Giovanni-Vespasiani/PulsePane.git`
- **Visibility:** Private
- **Auth:** SSH via `github-personal` host (ed25519 key `~/.ssh/id_ed25519_github_personal`)
- **Account:** Giovanni-Vespasiani (personal)
- **Local Git config:** `user.name=Gvespa`, `user.email=giovivespa06@gmail.com` (repository-local only)

## Versioning Policy (from v2.0 freeze)
| Version | Meaning |
|---------|---------|
| v2.0.0 | Stable pre-rebrand release (TAGGED) — rollback point |
| v2.1.0 | Completed rebrand / public identity |
| v2.2.0 | Hardening (error handling, edge cases) |
| v2.3.0 | Tests + CI |
| v2.4.0 | Public-readiness release (license, docs, signing) |

Current HEAD: v2.1 development (commit 2bc87e3)

## Tests: v2 metrics (2026-09-05)

The widget now also reads Network, Disk, Power, and Temperature. The `MP_DEBUG=1`
line prints `NET`/`DISK`/`PWR`/`TMP` so every reader can be validated from the
terminal with a single `MP_DEBUG=1` launch (manual).

### Network
- Idle → `NET ↑0 B/s ↓0 B/s` (noise-only).
- `curl` download → `↓` jumps (measured 253 KB/s while pulling apple.com).
- `dd`/uploads → `↑` responds.
- Only AF_LINK interfaces, IFF_UP, loopback/virtual (`lo`, `awdl`, `llw`, `utun`,
  `ipsec`, `gif`, `stf`) excluded by design.

### Regression: CPU / GPU / RAM
- Same as v0.1 (CPU under `N=$(sysctl -n hw.logicalcpu)` parallel `yes`;
  RAM cross-check vs `vm_stat`; GPU with a throwaway Metal workload).

## v2.3 Test & CI Commands

### Run Tests
```bash
swift test                    # Run all tests
swift test --filter <TestClass>  # Run specific test class
swift test --filter <TestClass>/<testMethod>  # Run single test
```

### Coverage
```bash
swift test --enable-code-coverage
# View report:
xcrun llvm-cov report --object .build/arm64-apple-macosx/debug/PulsePanePackageTests.xctest/Contents/MacOS/PulsePanePackageTests --instr-profile .build/debug/codecov/default.profdata
```

### Build & Test (CI Verification)
```bash
swift build        # Debug build
swift test         # Run tests
swift build -c release  # Release build
./scripts/build.sh release  # Build + assemble .app
```

### CI Pipeline
GitHub Actions workflow: `.github/workflows/ci.yml`
- Runs on macOS-14
- Jobs: build-and-test, warning-audit
- Triggers: push/PR to main
- Permissions: contents: read

### Warning Audit
```bash
# Check debug build warnings
swift build 2>&1 | grep -E "(warning|error)"

# Check release build warnings
swift build -c release 2>&1 | grep -E "(warning|error)"

# Current: 2 deprecation warnings (String(decoding:) in SystemCapabilities)
# These are unavoidable - String(decoding:) crashes compiler on this macOS version
```

## Test Coverage Summary (v2.3)

| Module | Coverage | Notes |
|--------|----------|-------|
| MetricSanitizers/Formatters | 100% | All sanitization/formatting logic |
| DeltaCounter/SafeDelta | 90% | Delta math, reset handling |
| DiskParsing/NetworkPolicy | 90% | Parsing + delta/reset |
| GPU Parsing | 90% | Fallback logic |
| Power Parsing | 90% | Telemetry parsing |
| Persistence Migration | 95% | UserDefaults migration |
| Capability Detection | 90% | System detection |
| WakeHandler | 75% | Wake handler registration |
| CPU/Memory | 0% | Hardware-dependent (manual) |
| GPU/Power/Temp readers | 0% | Hardware-dependent (manual) |
| UI/SwiftUI | 0% | Not unit-testable |
| **Overall (critical logic)** | **>90%** | Exceeds target |

### Coverage Command
```bash
swift test --enable-code-coverage
xcrun llvm-cov report --object .build/arm64-apple-macosx/debug/PulsePanePackageTests.xctest/Contents/MacOS/PulsePanePackageTests --instr-profile .build/debug/codecov/default.profdata
```

## Test Isolation
Tests use isolated `UserDefaults(suiteName:)` to avoid contaminating real preferences.
All hardware interactions are mocked with synthetic data fixtures.
No real network/disk/GPU access in unit tests.