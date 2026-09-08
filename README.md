# PulsePane

Your Mac, at a glance.

A beautiful, native real-time desktop system monitor for Apple Silicon.
Native Swift + SwiftUI + AppKit. Apple Silicon only (arm64).

## What it is
A dark glass "widget-style" panel that stays on the desktop and shows *real*
live metrics, refreshed ~every second:
- CPU usage (global %, with live circular ring)
- GPU usage (global %, when readable, with circular ring)
- Memory (used GB / total GB, %, thin circular ring)
- Network upload/download rate (with Wi-Fi link quality)
- System power draw (watts, internal/debug)
- Temperature (SoC) and CPU frequency — intentionally `—` where no clean
  non-privileged API exists (see Known limitations).

## v2.4 — Native Desktop Experience
- **Mission Control/Spaces**: Hidden in overview, visible on desktop
- **Fullscreen Apps**: Stays below fullscreen apps
- **Light/Dark Mode**: Automatic, live switching
- **Accessibility**: Reduce Transparency, Increase Contrast, Reduce Motion
- **Native Shape**: 28pt continuous corners, subtle shadow, no rectangular artifacts
- **Edge Snapping**: Magnetic snapping to screen edges (20pt threshold)
- **Multi-Display**: Recovers position on display changes
- **Native Feel**: No Dock icon, no focus stealing, drag anywhere

## v2.0/v2.1/v2.2/v2.3/v2.4 goals
- **v2.0**: Working stable desktop widget with real CPU/GPU/RAM data
- **v2.1**: Complete rebrand to PulsePane with professional identity
- **v2.2**: Runtime hardening (window level, safe counters, wake handling)
- **v2.3**: Automated tests (134), GitHub Actions CI, warning audit
- **v2.4**: Native desktop experience — Mission Control, Light/Dark, snapping, rings

## Main requirements
- Native Apple APIs only (Mach, IOKit, AppKit, SwiftUI, CoreWLAN)
- No Electron/webview, no external frameworks, no subprocess per tick
- ~1s refresh, very low CPU overhead (~1.3% CPU / ~78 MB RSS)
- Dark, macOS-like widget UI; medium widget footprint (≈340×430 pt)
- Frameless, draggable, hidden from Dock, persistent position, sits behind normal windows

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
│   ├── Models/       (SystemStats, Sanitizers)
│   ├── Monitoring/   (SystemMonitor, MetricSampler, WakeHandler, SystemCapabilities,
│   │                  SafeDelta, CPU/GPU/Memory/Network/Disk/Power/Temperature
│   │                  readers, NetworkQualityReader, DesktopGeometry, PerformanceModel)
│   └── Views/        (PerformanceWidgetView, RoundedHostingView, CircularProgressRing,
│                      MetricRingRow, NetworkMetricRow, etc.)
├── scripts/          (build/run/make-app helpers)
├── README.md
├── DEVELOPMENT.md
├── ARCHITECTURE.md
├── PROJECT_STATE.md
├── DECISIONS.md
├── docs/
│   ├── HARDENING.md
│   ├── TESTING.md
│   └── NATIVE_DESKTOP_EXPERIENCE.md
```

## APIs used
- **CPU:** Mach `host_processor_info` (PROCESSOR_CPU_LOAD_INFO) — tick deltas across user/system/nice/idle.
- **RAM:** `host_statistics64` — used = active + wired + compressed; total via `hw.memsize`. See DECISIONS D-003.
- **GPU:** IOKit `IORegistryEntryCreateCFProperty` reading `PerformanceStatistics` on the `IOAccelerator` service (class `AGXAcceleratorG16G` on this M4).
- **Network:** `getifaddrs` AF_LINK counters, 1 s delta → ↑/↓ bytes/s (excludes loopback/virtual interfaces).
- **Disk:** IOKit `IOBlockStorageDriver` `Statistics`, 1 s delta → R/W bytes/s.
- **Power:** IOKit `AppleSmartBattery` → `PowerTelemetryData` `SystemLoad` (mW) → watts. See DECISIONS D-010.

## Known limitations
- GPU counters: empirical driver properties (`Device/Renderer/Tiler Utilization %`), **not a documented stable Apple API**. Verified on Apple M4 (Mac16,13) / macOS 26.6.2.
- **SoC temperature:** no clean non-privileged API on Apple Silicon (battery `Temperature` and NVMe sensors exist but are not the SoC; `IOReport` thermal channels are private dylib/unknown units) → UI shows `—`. DECISIONS D-011.
- **CPU frequency:** no non-privileged live-frequency API on Apple Silicon → CPU sub-label shows "M4", not a GHz figure. DECISIONS D-009.
- Power is Apple telemetry (an estimate), cross-validated against boot-time average; not a lab power meter. Idle ≈ 5.9–8.4 W depending on system state.
- Memory "used" is our semantically-coherent approximation, **not** a byte-for-byte replica of Activity Monitor.

## License / status
Local development project. Not published; v2.4 in development.