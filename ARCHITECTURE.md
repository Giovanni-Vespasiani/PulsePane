# ARCHITECTURE.md — PulsePane v2.1

## Module structure
```
App/PulsePaneApp.swift           App entry point; drives WindowController.
App/WindowController.swift       NSWindow setup: frameless, level, drag, persistence, size.
Models/SystemStats.swift         Immutable Sendable snapshot: all v1+v2 metrics (Optional = unavailable).
Models/ByteRate.swift            Rate/power/temperature formatters for the v2 UI.
Monitoring/SystemMonitor.swift   Coordinator: 1s sampling loop, publishes SystemStats on @MainActor.
Monitoring/CPUReader.swift       Mach host_processor_info tick deltas → global CPU %.
Monitoring/GPUReader.swift       IOKit IOAccelerator PerformanceStatistics → Optional GPU %.
Monitoring/MemoryReader.swift    host_statistics64 → used + total.
Monitoring/NetworkReader.swift   getifaddrs AF_LINK byte counters, delta → ↑/↓ bytes/s.
Monitoring/DiskReader.swift      IOBlockStorageDriver Statistics, delta → R/W bytes/s.
Monitoring/PowerReader.swift     AppleSmartBattery PowerTelemetryData.SystemLoad (mW) → watts.
Monitoring/TemperatureReader.swift  SoC temp — currently nil (see DECISIONS D-011).
Monitoring/MetricSampler.swift   Owns all readers, produces one SystemStats per tick.
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
  thread, builds `SystemStats`, publishes to the `@MainActor` model.
- **SystemStats** is an immutable value type the UI observes.
- **Views** render `SystemStats`; no logic.

## Data flow
```
Readers (CPU, GPU, Memory, Network, Disk, Power, Temperature)
        ↓  raw values
MetricSampler (sample context, previous-tick deltas)
        ↓  SystemStats (one per ~1 s)
SystemMonitor (background sampling task)
        ↓  MainActor publish (@Published)
PerformanceModel
        ↓
SwiftUI (PerformanceWidgetView)
```

## Threading / concurrency
- Sampling & elaboration (Mach/IOKit/getifaddrs reads) run **off the main thread**
  (detached utility task). See DECISIONS D-007.
- Results marshalled to `@MainActor @Published`; SwiftUI never blocks on slow reads.
- Swift 6 strict concurrency respected: `SystemStats` is `Sendable`; sampler is
  `@unchecked Sendable` with state confined to its single sampling context.

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

## Bundle / app packaging
- SPM executable + `scripts/make-app.sh` → `.app` (Info.plist with `LSUIElement`).

## Dependencies between components
- `MetricSampler` → all readers + `SystemStats`.
- `SystemMonitor` → `MetricSampler`, `PerformanceModel`.
- `PerformanceWidgetView` → `PerformanceModel`, row components, `ByteRate`, `MiniHistogram`.
- `WindowController` → the SwiftUI view.
- Readers are independent and replaceable; Network/Disk/Power/Temperature are
  isolated exactly like GPUReader was (driver/kernel property surface may change).

## GPU implementation notes (unstable surface — same as v0.1)
- Reads `PerformanceStatistics` from the single `IOAccelerator` service. Keys are
  empirical driver properties, not a stable Apple API. Isolated in GPUReader.
- Fallbacks: Renderer % → Tiler % → nil.

## Availability rules (v2)
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