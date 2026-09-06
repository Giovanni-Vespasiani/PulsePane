import Foundation

/// Safe counter delta computation.
///
/// Handles the common patterns in metric sampling:
/// - First sample (no previous baseline) → returns nil
/// - Counter reset/rollover (new < old) → returns nil, caller should reset baseline
/// - Zero elapsed time → returns nil
/// - Valid delta → returns rate per second
///
/// All readers using delta sampling (CPU, Network, Disk, etc.) should
/// use this utility or equivalent logic to ensure consistent behavior.
enum SafeDelta {

    /// Result of a delta computation.
    struct Result: Sendable {
        /// Rate per second (bytes/sec, ticks/sec, etc.)
        let rate: Double
        /// True if this is the first sample (no previous baseline).
        let isFirstSample: Bool
        /// True if counter reset/wraparound was detected.
        let didReset: Bool
    }

    /// Computes a safe rate from two counter readings.
    ///
    /// - Parameters:
    ///   - new: Current counter value (monotonic increasing).
    ///   - old: Previous counter value.
    ///   - elapsed: Time interval in seconds between readings.
    /// - Returns: Result with rate and metadata, or nil if elapsed <= 0.
    static func rate(new: UInt64, old: UInt64, elapsed: TimeInterval) -> Result? {
        guard elapsed > 0 else { return nil }

        if new < old {
            // Counter reset or wraparound detected.
            return Result(rate: 0, isFirstSample: false, didReset: true)
        }

        let delta = new - old
        let rate = Double(delta) / elapsed
        return Result(rate: rate, isFirstSample: false, didReset: false)
    }

    /// Computes a safe rate for the first sample (no previous baseline).
    ///
    /// Returns nil to indicate no rate can be computed yet.
    /// Caller should record the current value as baseline for next sample.
    static func firstSample() -> Result? {
        return Result(rate: 0, isFirstSample: true, didReset: false)
    }
}

/// A thread-safe wrapper for a monotonic counter with delta computation.
///
/// Encapsulates the previous value and provides a safe `sample(newValue:interval:) -> Double?`
/// method that returns the rate per second or nil on first sample/reset.
///
/// Usage:
/// ```swift
/// let counter = DeltaCounter()
/// func read() -> Double? {
///     let newValue = readHardwareCounter()
///     let rate = counter.sample(newValue: newValue, interval: 1.0)
///     return rate
/// }
/// ```
final class DeltaCounter: @unchecked Sendable {
    private var previous: UInt64?
    private var haveSample = false

    /// Records a new counter value and returns the computed rate per second.
    ///
    /// - Parameters:
    ///   - newValue: Current counter reading.
    ///   - interval: Time in seconds since last sample.
    /// - Returns: Rate per second, or nil if this is the first sample
    ///            or a counter reset was detected.
    func sample(newValue: UInt64, interval: TimeInterval) -> Double? {
        guard interval > 0 else { return nil }

        defer { previous = newValue; haveSample = true }

        guard haveSample else { return nil } // First sample

        guard newValue >= previous! else { return nil } // Reset/wraparound

        let delta = newValue - previous!
        return Double(delta) / interval
    }

    /// Resets the counter state (e.g., after sleep/wake).
    func reset() {
        previous = nil
        haveSample = false
    }

    /// Checks if the counter has a valid baseline.
    var hasBaseline: Bool { haveSample }
}