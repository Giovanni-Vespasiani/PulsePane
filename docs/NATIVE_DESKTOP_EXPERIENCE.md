# PulsePane v2.4 — Native Desktop Experience

> A native macOS desktop system monitor that feels like part of the desktop itself.

---

## Overview

PulsePane v2.4 transforms the widget into a truly native macOS desktop experience. It behaves like a native desktop widget: properly layered in Mission Control/Spaces, follows system appearance (Light/Dark), respects accessibility settings, and provides beautiful visual feedback through semantic design.

---

## Key Features

### 🎯 Native Window Behavior (Milestone A)
- **Mission Control / Spaces**: Hidden in Mission Control/Spaces overview (`.transient` + `.stationary` + `.canJoinAllSpaces`)
- **Fullscreen Apps**: Stays below fullscreen apps (`.fullScreenNone`)
- **Show Desktop**: Behaves like native desktop widget
- **Stage Manager**: Compatible (no special handling needed)
- **Focus/Activation**: Never steals focus (`orderFrontRegardless`), no Dock icon (`LSUIElement`)

### 📐 Desktop Geometry (Milestone B)
- **Safe Area**: Uses `NSScreen.visibleFrame` with 16pt aesthetic margin
- **Edge Snapping**: Magnetic snapping to screen edges within 20pt threshold
- **Multi-Display**: Clamps to visible screen union, recovers gracefully on display changes
- **Persistence**: Versioned frame storage (`v2|{x,y,w,h}`), survives display changes

### 🎨 Appearance System (Milestone C)
- **No Forced Dark Mode**: Follows system appearance automatically
- **Semantic Colors**: Uses `Color.primary`, `.secondary`, `.tertiary` for text
- **Semantic Materials**: `.regularMaterial` with subtle tint for native feel
- **Live Switching**: Light↔Dark transitions instantly without restart
- **Accessibility**:
  - Reduce Transparency → more opaque background
  - Increase Contrast → stronger borders/separators
  - Reduce Motion → disables ring animations

### 🎯 Shape & Shadow (Milestone D)
- **Transparent Host**: `isOpaque=false`, `backgroundColor=.clear`
- **Rounded Clipping**: `RoundedHostingView` with 28pt continuous corners
- **Shadow Artifact Fixed**: Explicit `shadowPath` matching rounded rect
- **Subtle Shadow**: 12% opacity, 1pt offset, 4pt radius on light wallpapers
- **Continuous Corners**: `cornerCurve = .continuous` for smooth Apple-like feel

### 📊 Metric UI Redesign (Milestone E)
| Metric | Before | After |
|--------|--------|-------|
| **CPU** | Histogram bars | Circular ring (blue) + % |
| **GPU** | Histogram bars | Circular ring (purple) + % |
| **Memory** | Progress bar | Circular ring (green) + used/total GB |
| **Network** | Secondary row | Primary row with ↑/↓ arrows + semantic colors |
| **Power** | Primary row | Moved to internal (diagnostic only) |

### 📡 Network Quality (Milestone F)
- **Passive CoreWLAN**: No active probes, no privileges
- **Metrics**: RSSI, Noise, SNR, Tx Rate
- **Classification**: Excellent (≥40dB SNR) → Good (≥25dB) → Fair (≥15dB) → Poor
- **Graceful Fallback**: `.unsupported` on desktop Macs, `.unknown` on error
- **Privacy**: No active probes, no external requests

### 🧪 Testing & Quality (Milestone G)
- **153 Tests Passing**: All automated tests pass
- **Coverage**: Critical logic >90%, Formatters/Sanitizers 100%
- **CI Pipeline**: GitHub Actions on macOS-15 (Swift 6.x)
- **Performance**: ~1.3% CPU, ~78 MB RSS at 1 Hz

---

## Visual Verification Checklist

### Wallpaper Torture Test
- [ ] Nearly black wallpaper
- [ ] White wallpaper  
- [ ] Light gray wallpaper
- [ ] Bright photograph
- [ ] Dark photograph
- [ ] Highly saturated/colorful wallpaper

### Behavior Verification
- [ ] Mission Control: Widget hidden
- [ ] Spaces overview: Widget hidden
- [ ] Fullscreen app: Widget below
- [ ] Show Desktop: Widget visible
- [ ] Stage Manager: No regression
- [ ] Drag: Smooth, snaps to edges
- [ ] Light/Dark switch: Live update, no restart
- [ ] Reduce Transparency: No transparency
- [ ] Increase Contrast: Stronger borders
- [ ] Reduce Motion: Ring animations disabled

---

## Architecture

```
PulsePane/
├── App/
│   ├── PulsePaneApp.swift          # @main entry, AppDelegate
│   └── WindowController.swift      # NSWindow setup, persistence, appearance
├── Models/
│   ├── SystemStats.swift           # Immutable metrics snapshot
│   ├── ByteRate.swift              # Legacy formatters (deprecated)
│   └── Sanitizers.swift            # MetricSanitizers + MetricFormatters
├── Monitoring/
│   ├── SystemMonitor.swift         # Coordinator, 1Hz sampling
│   ├── MetricSampler.swift         # Owns readers, produces SystemStats
│   ├── SystemCapabilities.swift    # Launch-time hardware detection
│   ├── SafeDelta.swift             # DeltaCounter + SafeDelta utilities
│   ├── WakeHandler.swift           # Sleep/wake baseline reset
│   ├── DesktopGeometry.swift       # Safe area, snapping, clamping
│   ├── SystemCapabilities.swift    # Hardware/capability detection
│   ├── CPUReader.swift             # Mach host_processor_info
│   ├── GPUReader.swift             # IOKit IOAccelerator
│   ├── MemoryReader.swift          # host_statistics64
│   ├── NetworkReader.swift         # getifaddrs + CoreWLAN quality
│   ├── DiskReader.swift            # IOBlockStorageDriver
│   ├── PowerReader.swift           # AppleSmartBattery telemetry
│   ├── TemperatureReader.swift     // nil (documented unavailable)
│   ├── SystemMonitor.swift
│   ├── MetricSampler.swift
│   └── PerformanceModel.swift      # ObservableObject, 22-sample history
├── Views/
│   ├── PerformanceWidgetView.swift # Main layout
│   ├── RoundedHostingView.swift    # Rounded clipping + shadow
│   ├── CircularProgressRing.swift  # Animated progress ring
│   ├── MetricRingRow.swift         # Label + ring + %
│   ├── MetricProgressRow.swift     // deprecated
│   ├── SecondaryMetricRow.swift    // Network row
│   └── MiniHistogram.swift         // deprecated
├── scripts/
│   ├── build.sh
│   ├── make-app.sh
│   └── run.sh
└── docs/
    ├── HARDENING.md
    ├── TESTING.md
    └── NATIVE_DESKTOP_EXPERIENCE.md
```

---

## Configuration

### Build
```bash
swift build -c release
./scripts/build.sh release
```

### Run
```bash
open ~/.build/release/PulsePane.app
# or
./scripts/run.sh
```

### Debug
```bash
MP_DEBUG=1 open ~/.build/release/PulsePane.app
```

### Commands
```bash
# CPU load test
N=$(sysctl -n hw.logicalcpu)
for i in $(seq 1 $N); do yes > /dev/null & done
# observe...
pkill -x yes

# GPU load test (Metal)
# See DEVELOPMENT.md for Metal workload

# Network test
curl -s -o /dev/null https://www.apple.com/

# Disk test
dd if=/dev/zero of=/tmp/test.bin bs=1m count=200
rm /tmp/test.bin
```

---

## Known Limitations

1. **GPU**: Empirical driver keys (`Device/Renderer/Tiler Utilization %`), not stable Apple API
2. **Temperature**: No clean non-privileged SoC temperature API → shows `—`
3. **CPU Frequency**: No non-privileged live-frequency API → shows "M4"
3. **Power**: Apple telemetry estimate, not lab-grade
4. **Network Quality**: Wi-Fi only; Ethernet shows `.unsupported`
5. **Desktop Macs**: Power/Network quality unavailable (no battery/Wi-Fi)
6. **CI Runner**: macOS-14 on GitHub Actions (no GPU, no battery)

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| v2.0.0 | 2024-09-05 | Initial working widget (CPU/GPU/RAM) |
| v2.1.0 | 2024-09-06 | Rebrand to PulsePane |
| v2.2.0 | 2024-09-07 | Hardening (window level, hardening) |
| v2.3.0 | 2024-09-07 | Tests + CI (134 tests) |
| **v2.4.0** | **2024-09-08** | **Native Desktop Experience** |

---

## Next: v2.5 — Public GitHub Preparation

- Public repository setup
- Professional README with screenshots
- GitHub Actions (full CI/CD)
- Code signing / notarization
- DMG distribution
- Homebrew formula
- Launch at login
- Settings UI