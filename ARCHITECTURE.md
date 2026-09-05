# ARCHITECTURE.md — MacPerformance v0.1

## Module structure
```
App/MacPerformanceApp.swift     App entry point; drives WindowController.
App/WindowController.swift      NSWindow setup: frameless, level, drag, persistence.
Models/SystemStats.swift        Immutable snapshot: cpuUsage, gpuUsage?, memoryUsed, memoryTotal.
Monitoring/SystemMonitor.swift  Coordinator: 1s sampling loop, owns readers, publishes SystemStats.
Monitoring/CPUReader.swift      Mach host_processor_info tick deltas → global CPU %.
Monitoring/GPUReader.swift      IOKit IOAccelerator PerformanceStatistics → Optional GPU %.
Monitoring/MemoryReader.swift   host_statistics64 → used + total.
Views/PerformanceWidgetView.swift  SwiftUI widget layout.
Views/MetricRow.swift           Single metric row (label + value + thin bar).
```

## Responsibilities
- **Readers** own exactly one subsystem (CPU / GPU / RAM) and return raw numbers.
  They never touch the UI.
- **SystemMonitor** is the coordinator. It schedules sampling, calls each reader,
  builds a `SystemStats`, and publishes it.
- **SystemStats** is an immutable value type that the UI observes.
- **Views** render `SystemStats`; no logic.

## Data flow
```
Readers (CPUReader, GPUReader, MemoryReader)
        ↓  raw values
SystemMonitor (sampling queue / Timer)
        ↓  builds SystemStats
MainActor (publish via @Published / ObservableObject)
        ↓
SwiftUI (PerformanceWidgetView)
```

## Threading / concurrency
- Sampling & elaboration (Mach/IOKit reads) run **off the main thread**
  (Task/Timer on a background queue / detached sampling loop).
- Results are marshalled to `@MainActor @Published` so SwiftUI never blocks on a
  slow read. See DECISIONS D-007.
- Swift 6 strict concurrency is respected (Sendable for SystemStats, @MainActor
  for the observable model).

## WindowController / AppKit
- Frameless `NSWindow` (`[.borderless]`), `isMovableByWindowBackground = true`
  for click-and-drag.
- `LSUIElement = YES` in Info.plist → no Dock icon.
- Window level chosen **empirically** (see DECISIONS D-006 and PROJECT_STATE.md):
  start with `.desktop` / `CGWindowLevelForKey(.desktopWindowLevel)`, verify
  Finder / normal windows / Spaces / Mission Control / show-desktop, then lock
  the minimal level that gives correct in-front/behind behavior.
- Native material background (`NSVisualEffectView`, dark) for the widget look.

## Position persistence
- Save window frame/position to `UserDefaults` on move.
- On launch, restore it but clamp to the union of visible `NSScreen` frames so a
  saved position never lands off-screen after a display change / unplug.

## Bundle / app packaging
- SPM builds an executable; `scripts/make-app.sh` assembles the `.app` bundle
  (Contents/{Info.plist, MacOS/, Resources/}). Info.plist carries `LSUIElement`.
  No `__TEXT,__info_plist` linker trick unless a concrete need arises.

## Dependencies between components
- `SystemMonitor` → `CPUReader`, `GPUReader`, `MemoryReader` (and `SystemStats`).
- `WindowController` → (implicitly) the SwiftUI `PerformanceWidgetView`.
- Readers are independent and replaceable; GPUReader is intentionally isolated.

## GPU implementation notes (unstable surface)
- Reads `PerformanceStatistics` from the single `IOAccelerator` service.
- On this M4: service class `AGXAcceleratorG16G`, `CFBundleIdentifier`
  `com.apple.AGXG16G`, `IONameMatched` `gpu,t8132`, `MetalPluginName`
  `AGXMetalG16G_B0`. Present keys: `Device Utilization %`, `Renderer Utilization %`,
  `Tiler Utilization %`.
- `IORegistryEntryCreateCFProperty` is a public IOKit API, but the dictionary
  **keys are empirical driver properties**, not a documented stable Apple API.
  Compatibility risk: key/type may change across hardware/OS. Isolated in
  GPUReader so it can be swapped without touching the rest.
- Fallbacks: Renderer % → Tiler % → declare GPU unavailable (nil) rather than invent.
