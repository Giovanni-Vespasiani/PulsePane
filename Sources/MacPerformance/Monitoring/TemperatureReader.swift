import Foundation

/// SoC temperature reader — **currently unavailable without privileges**.
///
/// # Investigation on this Mac (Apple M4 / macOS 26.6.2), 2026-09-05
/// Candidates that were found and rejected as "not a reliable, non-privileged
/// SoC temperature":
/// - `AppleSmartBattery` → `Temperature` (raw 3069 → deci-Kelvin ≈ 33.7 °C):
///   a *battery* temperature, not SoC.
/// - `AppleEmbeddedNVMeTemperatureSensor`: NVMe controller temperature, not SoC.
/// - `IOReport` `MSP0`/`MSP1` `"Temperature(0)"` channels: only reachable via
///   the private `/usr/lib/libIOReport` dylib (no public Swift module), units
///   unknown (unit code 0). Rejected as fragile / unverifiable.
///
/// # Decision
/// `celsius()` returns `nil` (UI shows `—`). We do NOT label battery or NVMe
/// readings as "SoC temperature", and we do NOT invent values.
/// If a clean public API appears later, this reader is where it goes.
final class TemperatureReader: @unchecked Sendable {

    func celsius() -> Double? {
        nil
    }
}