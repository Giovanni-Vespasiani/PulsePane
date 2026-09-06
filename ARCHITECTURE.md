# ARCHITECTURE.md — PulsePane v2.2

## Module structure
```
App/PulsePaneApp.swift           App entry point; drives WindowController + WakeHandler + capabilities.
App/WindowController.swift       NSWindow setup: frameless, level, drag, persistence, size.
Models/SystemStats.swift         Immutable Sendable snapshot: all v1+v2 metrics (Optional = unavailable).
Models/ByteRate.swift            Legacy rate/power/temperature formatters (deprecated, kept for compat).
Models/Sanitizers.swift          MetricSanitizers + MetricFormatters (v2.2 sanitization/formatting).
Monitoring/SystemMonitor.swift   Coordinator: 1s sampling loop, WakeHandler, publishes SystemStats.
Monitoring/MetricSampler.swift   Owns all readers, produces one SystemStats per tick.
Monitoring/CPUReader.swift       Mach host_processor_info tick deltas → global CPU % (zero-delta safe).
Monitoring/GPUReader.swift       IOKit IOAccelerator PerformanceStatistics → Optional GPU % (cached, fallbacks).
Monitoring/MemoryReader.swift    host_statistics64 → used + total (checked arithmetic).
Monitoring/NetworkReader.swift   getifaddrs AF_LINK byte counters, delta → ↑/↓ bytes/s (safe delta, policy).
Monitoring/DiskReader.swift      IOBlockStorageDriver Statistics, delta → R/W bytes/s (safe delta, policy).
Monitoring/PowerReader.swift     AppleSmartBattery PowerTelemetryData.SystemLoad (mW) → watts (bounds).
Monitoring/TemperatureReader.swift  SoC temp — currently nil (see DECISIONS D-011).
Monitoring/SystemCapabilities.swift  Launch-time hardware/capability detection.
Monitoring/SafeDelta.swift       SafeDelta + DeltaCounter (shared delta logic).
Monitoring/WakeHandler.swift     NSWorkspace sleep/wake → baseline reset for delta readers.
Monitoring/PerformanceModel.swift  ObservableObject published to SwiftUI; 22-sample histories.
Views/PerformanceWidgetView.swift  v2 SwiftUI layout: header + CPU/GPU/Memory + secondary rows.
Views/MiniHistogram.swift        Bar chart (22 thin vertical bars) for CPU/GPU.
Views/MetricHistogramRow.swift   CPU/GPU row: label+secondary, histogram, fixed-width %.
Views/MetricProgressRow.swift    Memory row: label+GB text, %, title-full-width progress bar.
Views/SecondaryMetricRow.swift   Network/Disk rows: label + two aligned value pairs.
```

## Responsibilities
- **Readers** own exactly one subsystem (CPU / GPU / RAM / Network / Disk / Power /
  Temperature) and return raw numbers; `nil` means "unavailable this tick", never
  fake-zero. They never touch the UI.
- **MetricSampler** instantiates every reader and produces one `SystemStats` per
  tick. Its delta readers (Network/Disk/Power/GPU/CPU) keep previous-tick state
  inside the sampler's thread context only.
- **SystemMonitor** is the coordinator: detached sampling task off the main
  thread, owns WakeHandler, builds `SystemStats`, publishes to the `@MainActor` model.
- **SystemCapabilities** — one-shot hardware/capability detection at launch.
- **WakeHandler** — NSWorkspace sleep/wake notifications → resets all delta baselines.
- **SystemStats** is an immutable value type the UI observes.
- **Views** render `SystemStats` via sanitizers/formatters; no logic.

## Data flow
```
Readers (CPU, GPU, Memory, Network, Disk, Power, Temperature)
        ↓  raw values
MetricSampler (sample context, previous-tick deltas)
        ↓  SystemStats (one per ~1 s)
SystemMonitor (background sampling task + WakeHandler)
        ↓  MainActor publish (@Published)
PerformanceModel
        ↓
SwiftUI (PerformanceWidgetView) → Sanitizers → Formatters
```

## Threading / concurrency
- Sampling & elaboration (Mach/IOKit/getifaddrs reads) run **off the main thread**
  (detached utility task). See DECISIONS D-007.
- WakeHandler runs on main thread (NSWorkspace notifications).
- Results marshalled to `@MainActor @Published`; SwiftUI never blocks on slow reads.
- Swift 6 strict concurrency respected: `SystemStats` is `Sendable`; sampler is
  `@unchecked Sendable` with state confined to its single sampling context.
- WakeHandler is `@MainActor` isolated (NSWorkspace notifications).

## WindowController / AppKit
- Frameless `NSWindow` (`[.borderless]`), `isMovableByWindowBackground = true`.
- `LSUIElement = YES` → no Dock icon.
- Window level = `kCGDesktopIconWindowLevel + 1` (see DECISIONS D-006):
  above Finder desktop + wallpaper, below all normal windows.
- collectionBehavior `[.stationary, .canJoinAllSpaces, .ignoresCycle]`.
- v2 default size 340×395 (final content height lands ~395–400; width fixed 340).
- Position persistence is **versioned** (`"v2|…"` in UserDefaults): saved origin is
  reused but size is always reset to the v2 default, so a stale v1 frame never
  distorts the new layout.
- Enhanced validation: malformed/off-screen/legacy frames handled safely.

## Bundle / app packaging
- SPM executable + `scripts/make-app.sh` → `.app` (Info.plist with `LSUIElement`).

## Dependencies between components
- `MetricSampler` → all readers + `SystemStats`.
- `SystemMonitor` → `MetricSampler`, `PerformanceModel`, `WakeHandler`.
- `PerformanceWidgetView` → `PerformanceModel`, row components, `MetricSanitizers`, `MetricFormatters`.
- `WindowController` → the SwiftUI view.
- Readers are independent and replaceable; Network/Disk/Power/Temperature are
  isolated exactly like GPUReader was (driver/kernel property surface may change).
- WakeHandler registers delta readers (CPU, Network, Disk, GPU) for baseline reset.

## GPU implementation notes (unstable surface — same as v0.1)
- Reads `PerformanceStatistics` from the single `IOAccelerator` service. Keys are
  empirical driver properties, not a stable Apple API. Isolated in GPUReader.
- v2.2: service caching with `invalidate()`, fallback priority order, value validation.
- Fallbacks: Device % → Renderer % → Tiler % → nil.

## Availability rules (v2.2)
| Metric         | Source                              | Non-privileged? | Status on M4 |
|----------------|-------------------------------------|-----------------|--------------|
| CPU %          | Mach host_processor_info            | yes             | ✓ real      |
| GPU %          | IOKit PerformanceStatistics         | yes             | ✓ real      |
| Memory         | host_statistics64                   | yes             | ✓ real      |
| Network ↑/↓    | getifaddrs delta                    | yes             | ✓ real      |
| Disk R/W       | IOBlockStorageDriver delta          | yes             | ✓ real      |
| Power (W)      | AppleSmartBattery SystemLoad        | yes             | ✓ real, ~8 W idle |
| SoC Temp (°C)  | — (no clean non-privileged API)     | —               | → nil (UI `—`) |
| CPU GHz        | — (nothing non-privileged)          | —               | → nil (UI `—`) |

For the SoC temp / CPU freq investigation details, see PROJECT_STATE.md and
DECISIONS D-009 / D-011.