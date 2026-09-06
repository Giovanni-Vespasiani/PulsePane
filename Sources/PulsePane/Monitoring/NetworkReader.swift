import Foundation
import Darwin
import os

/// Reads live per-interface byte counters via `getifaddrs` (native, no
/// subprocess) and computes upload/download rate from the delta between two
/// samples (≈1 s apart).
///
/// # Interface Selection Policy
/// We aggregate counters from **active, non-loopback, physical-ish interfaces**
/// with AF_LINK (data-link) addresses. Specifically:
///
/// INCLUDED:
/// - Ethernet (en0, en1, etc.)
/// - Wi-Fi (en0 on Apple Silicon typically)
/// - Thunderbolt/USB Ethernet adapters
/// - Physical interfaces with IFF_UP and AF_LINK
///
/// EXCLUDED:
/// - `lo0` — loopback (IFF_LOOPBACK)
/// - `awdl*` — Apple Wireless Direct Link (peer-to-peer, high variance)
/// - `llw*` — Low Latency WLAN (Apple proprietary)
/// - `utun*` — VPN tunnels
/// - `ipsec*` — IPsec tunnels
/// - `gif*`, `stf*` — tunnel interfaces
/// - Inactive interfaces (not IFF_UP)
/// - Interfaces without AF_LINK (no byte counters)
///
/// This policy aims to measure "real" network traffic to/from the Internet/LAN
/// while excluding virtual/tunnel traffic that would distort the picture.
///
/// # Counter Handling
/// - Uses `SafeDelta` for safe delta computation
/// - Counter reset/rollover → returns nil, baseline reset
/// - First sample → returns nil, establishes baseline
/// - Negative delta (counter regression) → treated as reset, returns nil
///
/// # Error Handling
/// - `getifaddrs` failure → unavailable
/// - No eligible interfaces → unavailable
/// - Malformed `if_data` → interface skipped
/// - Counter reset → returns nil, baseline cleared
final class NetworkReader: @unchecked Sendable, WakeHandler.BaselineResettable {

    // MARK: - Configuration

    private struct Sample {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let date: Date
    }

    // Interface prefixes to exclude (virtual/tunnel/high-variance)
    private static let excludedPrefixes = [
        "lo",      // loopback
        "awdl",    // Apple Wireless Direct Link
        "llw",     // Low Latency WLAN
        "utun",    // VPN tunnels
        "ipsec",   // IPsec
        "gif",     // GIF tunnels
        "stf",     // 6to4 tunnels
    ]

    // MARK: - State

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "network")
    private var previous: Sample?
    private let inCounter = DeltaCounter()
    private let outCounter = DeltaCounter()

    // MARK: - Public API

    func read() -> (uploadPerSec: Double?, downloadPerSec: Double?) {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let addressList = interfacePointer else {
            logger.debug("Network: getifaddrs failed")
            inCounter.reset()
            outCounter.reset()
            return (nil, nil)
        }
        defer { freeifaddrs(interfacePointer) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var interfaceCount = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = addressList
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            guard let sockaddr = current.pointee.ifa_addr else { continue }
            guard sockaddr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            guard Self.isTrackedInterface(name) else { continue }

            let flags = current.pointee.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0 else { continue }
            guard (flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }

            guard let rawData = current.pointee.ifa_data else { continue }
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee

            // ifi_ibytes/ifi_obytes are UInt32 in if_data, cast to UInt64
            bytesIn += UInt64(data.ifi_ibytes)
            bytesOut += UInt64(data.ifi_obytes)
            interfaceCount += 1
        }

        logger.debug("Network: sampled \(interfaceCount) interfaces, in=\(bytesIn) out=\(bytesOut)")

        let now = Date()
        let interval = previous.map { now.timeIntervalSince($0.date) } ?? 0

        // Use safe delta counters
        let upload = inCounter.sample(newValue: bytesOut, interval: interval)
        let download = outCounter.sample(newValue: bytesIn, interval: interval)

        // Check for counter resets (counters return nil on reset)
        let inReset = bytesOut < (previous?.bytesOut ?? 0)
        let outReset = bytesIn < (previous?.bytesIn ?? 0)
        if inReset || outReset {
            logger.debug("Network: counter reset detected, resetting baselines")
            inCounter.reset()
            outCounter.reset()
        }

        previous = Sample(bytesIn: bytesIn, bytesOut: bytesOut, date: now)
        return (upload, download)
    }

    private static func isTrackedInterface(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return !excludedPrefixes.contains { name.hasPrefix($0) }
    // MARK: - WakeHandler.BaselineResettable

    func resetBaselines() {
        previous = nil
        inCounter.reset()
        outCounter.reset()
        logger.debug("Network: baselines reset (wake)")
    }
}