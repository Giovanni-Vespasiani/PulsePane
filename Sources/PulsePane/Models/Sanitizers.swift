import Foundation

/// Centralized metric sanitization and formatting helpers.
///
/// Ensures that impossible values are made impossible before rendering:
/// - NaN, infinity → nil (unavailable)
/// - Negative values for unsigned metrics → nil
/// - Values exceeding reasonable bounds → clamped or nil
/// - Formatters handle boundary transitions cleanly

enum MetricSanitizers {

    // MARK: - Percentage Sanitization

    /// Sanitizes a percentage value to [0, 100] range.
    /// Returns nil for NaN, infinity, or values that cannot be represented.
    static func percent(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite else { return nil }
        let clamped = min(max(v, 0), 100)
        return clamped
    }

    /// Sanitizes an optional percentage, returning nil for any invalid state.
    static func optionalPercent(_ value: Double?) -> Double? {
        percent(value)
    }

    // MARK: - Throughput Sanitization (bytes/sec)

    /// Sanitizes a throughput value (bytes/sec).
    /// Returns nil for NaN, infinity, negative, or unreasonably large values.
    static func throughput(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v >= 0 else { return nil }
        // Sanity check: reject absurdly large values (> 100 TB/s)
        guard v <= 100_000_000_000_000 else { return nil }
        return v
    }

    // MARK: - Power Sanitization (watts)

    /// Sanitizes a power value (watts).
    /// Returns nil for NaN, infinity, negative, or unreasonably large values.
    static func power(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v >= 0 else { return nil }
        // Sanity check: reject absurdly large values (> 500 W)
        guard v <= 500 else { return nil }
        return v
    }

    // MARK: - Temperature Sanitization (celsius)

    /// Sanitizes a temperature value (celsius).
    /// Returns nil for NaN, infinity, or values outside plausible range.
    static func temperature(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite else { return nil }
        // Plausible range for SoC: -50°C to 150°C
        guard v >= -50, v <= 150 else { return nil }
        return v
    }

    // MARK: - Memory Sanitization

    /// Sanitizes memory used/total bytes.
    /// Ensures 0 <= used <= total.
    static func memory(used: UInt64?, total: UInt64?) -> (used: UInt64, total: UInt64)? {
        guard let u = used, let t = total, t > 0 else { return nil }
        let used = min(u, t) // Clamp used to total
        return (used: used, total: t)
    }

    // MARK: - Frequency Sanitization (GHz)

    /// Sanitizes CPU frequency in GHz.
    /// Returns nil for NaN, infinity, negative, or implausible values.
    static func frequencyGHz(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v > 0 else { return nil }
        // Plausible range: 0.1 GHz to 10 GHz
        guard v >= 0.1, v <= 10 else { return nil }
        return v
    }

    // MARK: - General Sanitization

    /// Returns the value if it's finite and non-negative, nil otherwise.
    static func nonNegativeFinite(_ value: Double?) -> Double? {
        guard let v = value, v.isFinite, v >= 0 else { return nil }
        return v
    }
}

/// Formatter helpers for human-readable metric display.
enum MetricFormatters {

    // MARK: - Byte Rate Formatting

    /// Formats bytes per second into human-readable string.
    /// B/s → KB/s → MB/s → GB/s transitions at 1024 boundaries.
    static func byteRate(_ bytesPerSec: Double?) -> String {
        guard let b = MetricSanitizers.throughput(bytesPerSec) else { return "—" }
        let value = max(b, 0)

        switch value {
        case ..<1024:
            return String(format: "%.0f B/s", value)
        case ..<(1024 * 1024):
            return String(format: "%.1f KB/s", value / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB/s", value / (1024 * 1024))
        default:
            return String(format: "%.2f GB/s", value / (1024 * 1024 * 1024))
        }
    }

    // MARK: - Memory Formatting

    static func memoryUsed(_ bytes: UInt64?) -> String {
        guard let b = bytes else { return "—" }
        let gb = Double(b) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }

    static func memoryTotal(_ bytes: UInt64?) -> String {
        guard let b = bytes else { return "—" }
        let gb = Double(b) / (1024 * 1024 * 1024)
        return String(format: "%.0f GB", gb)
    }

    static func memoryPercent(used: UInt64?, total: UInt64?) -> String {
        guard let u = used, let t = total, t > 0 else { return "—" }
        let pct = (Double(u) / Double(t)) * 100
        return String(format: "%.0f%%", min(max(pct, 0), 100))
    }

    // MARK: - Power Formatting

    static func power(_ watts: Double?) -> String {
        guard let w = MetricSanitizers.power(watts) else { return "—" }
        return String(format: "%.1f W", w)
    }

    // MARK: - Temperature Formatting

    static func temperature(_ celsius: Double?) -> String {
        guard let c = MetricSanitizers.temperature(celsius) else { return "—" }
        return String(format: "%.0f°C", c)
    }

    // MARK: - Percentage Formatting

    static func percent(_ value: Double?) -> String {
        guard let p = MetricSanitizers.percent(value) else { return "—" }
        return String(format: "%.0f%%", p)
    }

    // MARK: - Frequency Formatting

    static func frequency(_ ghz: Double?) -> String {
        guard let f = MetricSanitizers.frequencyGHz(ghz) else { return "—" }
        return String(format: "%.2f GHz", f)
    }
}