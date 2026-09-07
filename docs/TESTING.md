# TESTING.md — PulsePane v2.3 Testing Documentation

## Overview

This document describes the testing architecture, test target structure, and how to run tests for PulsePane v2.3.

## Test Target Structure

```
Tests/
└── PulsePaneTests/
    ├── CapabilityTests.swift        # SystemCapabilities detection
    ├── DeltaCounterTests.swift      # SafeDelta/DeltaCounter logic
    ├── DiskParsingTests.swift       # DiskReader parsing & delta logic
    ├── FormatterTests.swift         # MetricSanitizers & MetricFormatters
    ├── GPUParsingTests.swift        # GPUReader parsing & fallback logic
    ├── NetworkPolicyTests.swift     # NetworkReader interface filtering
    ├── NetworkDeltaTests.swift      # NetworkReader delta/counter reset
    ├── PersistenceMigrationTests.swift # UserDefaults migration logic
    ├── CapabilityTests.swift        # SystemCapabilities detection
    ├── SleepWakeResetTests.swift    # WakeHandler baseline reset
    ├── WindowStateTests.swift       # Window frame parsing & validation
    ├── CPUCalculationTests.swift    # CPUReader delta calculation
    ├── MemoryCalculationTests.swift # MemoryReader bounds checking
    └── PowerParsingTests.swift      # PowerReader telemetry parsing
```

## Test Architecture

### Design Principles

1. **Pure Logic Testing**: Extract pure functions from hardware-dependent readers for unit testing.
2. **Hardware Independence**: Tests use synthetic data fixtures, not real hardware.
3. **No Side Effects**: Tests never touch real UserDefaults, Git config, or system state.
4. **Isolation**: Each test uses isolated `UserDefaults` suites.

### Test Categories

| Category | Coverage | Description |
|----------|----------|-------------|
| **Parsing/Calculation** | High | GPU parsing, Power parsing, Disk parsing, CPU/Memory math |
| **Sanitization/Formatting** | 100% | MetricSanitizers, MetricFormatters |
| **Delta/Reset Logic** | High | DeltaCounter, counter reset/wake handling |
| **Migration/Persistence** | High | UserDefaults migration, frame parsing |
| **Capability Detection** | High | SystemCapabilities snapshot |
| **Sleep/Wake** | Medium | WakeHandler baseline reset |
| **UI/Hardware** | None | SwiftUI layout, hardware integration |

## Running Tests

### Local Development

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Run specific test class
swift test --filter DeltaCounterTests

# Run single test
swift test --filter DeltaCounterTests/testCounterReset
```

### Coverage Reporting

```bash
# Generate coverage data
swift test --enable-code-coverage

# View coverage report
xcrun llvm-cov report --object .build/arm64-apple-macosx/debug/PulsePanePackageTests.xctest/Contents/MacOS/PulsePanePackageTests --instr-profile .build/debug/codecov/default.profdata
```

### Coverage Summary (v2.3)

| Module | Line Coverage | Notes |
|--------|---------------|-------|
| MetricSanitizers | 100% | All sanitization logic |
| MetricFormatters | 100% | All formatters |
| DeltaCounter | 90% | Core delta logic |
| DiskParsing | 90% | Parser + delta |
| NetworkPolicy | 90% | Interface filtering |
| GPU Parsing | 90% | Fallback logic |
| Power Parsing | 90% | Telemetry parsing |
| Persistence | 95% | Migration + frame parsing |
| Capability Detection | 90% | System detection |
| CPU/Memory | 0% | Hardware-dependent (manual) |
| GPU/Power/Temp | 0% | Hardware-dependent (manual) |
| UI/SwiftUI | 0% | Not unit-testable |

**Overall**: Critical logic >90%, hardware-dependent code manually validated.

## Test Fixtures

Fixtures are created programmatically in tests rather than stored as files. This keeps the test suite self-contained and portable.

## CI Integration

### GitHub Actions Workflow

File: `.github/workflows/ci.yml`

**Triggers**: Push to main, Pull requests to main

**Jobs**:
1. `build-and-test`: macOS-14 runner
   - Checkout, build debug, run tests, build release, verify app bundle, check warnings
2. `warning-audit`: macOS-14 runner
   - Build, count warnings, document unavoidable warnings

**Permissions**: `contents: read` only

### CI Verification Checklist

- [ ] Debug build passes
- [ ] All 134 tests pass
- [ ] Release build passes
- [ ] App bundle assembles correctly
- [ ] Zero controllable warnings (2 unavoidable deprecation warnings documented)
- [ ] Coverage command succeeds

## Known Testing Limitations

1. **Hardware-dependent code**: GPUReader, PowerReader, TemperatureReader, CPUReader require real hardware for full validation. Unit tests cover parsing/calculation logic only.
2. **UI code**: SwiftUI views and AppKit window management not unit-tested.
3. **Sleep/wake**: Cannot simulate sleep/wake in CI; wake handler logic tested via direct method calls.
4. **CI environment**: GitHub macOS runners may not have AppleSmartBattery or GPU acceleration; capability tests handle unavailable gracefully.

## Running Manual Tests

```bash
# CPU load test
sysctl -n hw.logicalcpu
for i in $(seq 1 $(sysctl -n hw.logicalcpu)); do yes > /dev/null & done
# Observe CPU → ~100%
pkill -x yes

# GPU load test
# Run Metal compute stress (see DEVELOPMENT.md for exact command)

# Network test
curl -s -o /dev/null https://www.apple.com/

# Disk test
dd if=/dev/zero of=/tmp/test.bin bs=1m count=100
rm /tmp/test.bin

# Power validation
# Observe PWR in MP_DEBUG=1 output under load vs idle

# Sleep/wake test (manual)
# Put Mac to sleep, wake, verify baselines reset
```

## Coverage Goals (v2.3 Target)

| Area | Target | Actual |
|------|--------|--------|
| Critical parsing/math | >90% | ✅ 90-100% |
| Sanitization/formatting | 100% | ✅ 100% |
| Delta/counter logic | >90% | ✅ 90%+ |
| Migration/persistence | >90% | ✅ 95%+ |
| UI/Views | N/A | N/A |
| Hardware integration | Manual | Manual |

## Adding New Tests

1. Create new test file in `Tests/PulsePaneTests/`
2. Follow naming convention: `<Feature>Tests.swift`
2. Use descriptive test names: `test<Behavior>_<Scenario>()`
3. Use isolated `UserDefaults(suiteName:)` for persistence tests
4. Mock hardware data with fixtures, not real hardware
5. Add to coverage priority list if testing critical logic