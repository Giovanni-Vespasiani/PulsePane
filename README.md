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

## v2.0 / v2.1 goals
- **v2.0:** a working, stable desktop widget showing real CPU/GPU/RAM data.
  No fake or simulated values. *(done)*
- **v2.1:** complete rebrand to PulsePane with professional identity. *(done)*

## Main requirements
- Native Apple APIs only (Mach, IOKit, AppKit, SwiftUI). No Electron/webview,
  no external frameworks, no subprocess spawning per tick.
- ~1s refresh, very low CPU overhead (measured ~0.6% CPU / ~78 MB RSS steady).
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

## Repository structure
```
PulsePane/
├── Package.swift
├── Sources/PulsePane/
│   ├── App/          (app entry, WindowController)
│   ├── Models/       (SystemStats, ByteRate)
│   ├── Monitoring/   (SystemMonitor, MetricSampler, CPU/GPU/Memory/Network/Disk/Power/Temperature
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
    └── REBRAND_PLAN.md
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
  (deci-mW) → watts. See DECISIONS D-010.

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
  state.
- Memory "used" is our semantically-coherent approximation, **not** a
  byte-for-byte replica of Activity Monitor.

## License / status
Local development project. Not published; v2.1 in development.