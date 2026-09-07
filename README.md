# PulsePane

Your Mac, at a glance.

A beautiful, native real-time desktop system monitor for Apple Silicon.

## What it is
A dark glass "widget-style" panel that stays on the desktop and shows *real*
live metrics, refreshed ~every second:
- CPU usage (global %, with a 22-bar live histogram)
- GPU usage (global %, when readable, with histogram)
- Memory (used GB / total GB, %, thin progress bar)
- Network upload/download rate
- Disk read/write rate
- System power draw (watts)
- Temperature (SoC) and CPU frequency — intentionally `—` where no clean
  non-privileged API exists (see Known limitations).

## v2.0 / v2.1 / v2.2 / v2.3 goals
- **v2.0:** a working, stable desktop widget showing real CPU/GPU/RAM data.
  No fake or simulated values. *(done)*
- **v2.1:** complete rebrand to PulsePane with professional identity. *(done)*
- **v2.2:** runtime hardening — defensive engineering, capability detection,
  lifecycle correctness, safe counter handling, sleep/wake resilience. *(done)*
- **v2.3:** automated tests & CI — 134 tests, GitHub Actions CI, warning audit. *(done)*

## Main requirements
- Native Apple APIs only (Mach, IOKit, AppKit, SwiftUI). No Electron/webview,
  no external frameworks, no subprocess spawning per tick.
- ~1s refresh, very low CPU overhead (measured ~1.3% CPU / ~79 MB RSS steady).
- Dark, macOS-like widget UI; medium widget footprint (≈340×395 pt).
- Frameless, draggable, hidden from Dock, persistent position, sits behind
  normal windows (not always-on-top).

## Not implemented
Battery health, fans, per-process list, settings UI, WidgetKit, iCloud,
App Store, notarization, updater, analytics.

## Build
Requires Xcode CLI properly configured (see DEVELOPMENT.md).

```sh
cd ~/Projects/PulsePane
scripts/build.sh          # builds release .app into ~/.build/release/PulsePane.app
```

## Run
```sh
scripts/run.sh            # or:
open ~/.build/release/PulsePane.app
```

Debug mode prints every sampled metric each second to stderr:
```sh
MP_DEBUG=1 open ~/.build/release/PulsePane.app
```

## Testing & CI

```sh
swift test                    # Run all 134 tests
swift test --enable-code-coverage  # With coverage report
swift test --filter <TestClass>   # Run specific test class
```

**Test Results (v2.3)**: 134 tests passing, 0 failures
- Critical logic coverage: >90% (parsing, sanitization, delta math, migration)
- Formatters & sanitizers: 100%
- UI/hardware integration: manual validation (see DEVELOPMENT.md)

**CI**: GitHub Actions on macOS-14
- Push/PR to main triggers: Debug build → Tests → Release build → App bundle verification
- Warning audit: 2 unavoidable deprecation warnings (String(decoding:) in SystemCapabilities)
- Workflow: `.github/workflows/ci.yml`

See `docs/TESTING.md` for complete test documentation.

## Repository structure
```
PulsePane/
├── Package.swift
├── Sources/PulsePane/
│   ├── App/          (app entry, WindowController)
│   ├── Models/       (SystemStats, ByteRate, Sanitizers)
│   ├── Monitoring/   (SystemMonitor, MetricSampler, WakeHandler, SystemCapabilities,
│   │                  SafeDelta, CPU/GPU/Memory/Network/Disk/Power/Temperature
│   │                  readers, PerformanceModel)
│   └── Views/        (PerformanceWidgetView, MiniHistogram, MetricHistogramRow,
│                      MetricProgressRow, SecondaryMetricRow)
├── scripts/          (build/run/make-app helpers)
├── README.md
├── DEVELOPMENT.md
├── ARCHITECTURE.md
├── PROJECT_STATE.md
├── DECISIONS.md
└── docs/
    ├── REBRAND_PLAN.md
    └── HARDENING.md
```

## APIs used
- **CPU:** Mach `host_processor_info` (PROCESSOR_CPU_LOAD_INFO) — tick deltas
  across user/system/nice/idle.
- **RAM:** `host_statistics64` — used = active + wired + compressed; total via
  `hw.memsize`. See DECISIONS D-003.
- **GPU:** IOKit `IORegistryEntryCreateCFProperty` reading `PerformanceStatistics`
  on the `IOAccelerator` service (class `AGXAcceleratorG16G` on this M4).
- **Network:** `getifaddrs` AF_LINK counters, 1 s delta → ↑/↓ bytes/s (excludes
  loopback/virtual interfaces).
- **Disk:** IOKit `IOBlockStorageDriver` `Statistics`, 1 s delta → R/W bytes/s.
- **Power:** IOKit `AppleSmartBattery` → `PowerTelemetryData` `SystemLoad`
  (deci-mW) → watts. See DECISIONS D-010 / D-H003.

## Known limitations
- GPU counters come from driver properties on `PerformanceStatistics`
  (`Device/Renderer/Tiler Utilization %`): **empirical, driver-provided keys,
  not a documented stable Apple API contract**. Verified on Apple M4 (Mac16,13)
  / macOS 26.6.2.
- **SoC temperature:** no clean non-privileged API on Apple Silicon (battery
  `Temperature` and NVMe sensors exist but are not the SoC; `IOReport` thermal
  channels are private dylib/unknown units) → UI shows `—`. DECISIONS D-011.
- **CPU frequency:** no non-privileged live-frequency API on Apple Silicon →
  CPU sub-label shows "M4", not a GHz figure. DECISIONS D-009.
- Power is Apple telemetry (an estimate), cross-validated against the boot-time
  average; it is not a lab power meter. Idle ≈ 5.9–8.4 W depending on system
  state. Unavailable on desktop Macs (no battery).
- Memory "used" is our semantically-coherent approximation, **not** a
  byte-for-byte replica of Activity Monitor.

## v2.2 Hardening highlights
- **Capability detection** at launch (SystemCapabilities)
- **Safe delta counters** (SafeDelta/DeltaCounter) for CPU/Network/Disk
- **GPUReader** service caching + wake invalidation
- **PowerReader** semantic honesty + bounds (0–500 W)
- **NetworkReader** virtual interface exclusion policy
- **DiskReader** physical driver filter (marker key)
- **WakeHandler** sleep/wake baseline reset for all delta readers
- **Metric sanitization** (MetricSanitizers) + formatting (MetricFormatters)
- **Sleep/wake** baseline reset via NSWorkspace notifications
- **Concurrency audit** — Swift 6 compliant, no data races
- **Resource cleanup audit** — all IOKit/Mach allocations balanced
- **30-min stability test** passed (79 MB RSS, ~1.3% CPU)

## License / status
Local development project. Not published; v2.2 in development.