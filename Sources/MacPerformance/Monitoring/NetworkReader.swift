import Foundation
import Darwin

/// Reads live per-interface byte counters via `getifaddrs` (native, no
/// subprocess) and computes upload/download rate from the delta between two
/// samples (≈1 s apart).
///
/// Interfaces ignored: `lo0` (loopback), `awdl`/`llw` (peer-to-peer/Apple
/// Wireless Direct, high-variance virtual), `utun` (VPN tunnels), inactive
/// (not IFF_UP) interfaces. Only data-link (AF_LINK) interfaces are summed
/// because they carry the byte counters.
final class NetworkReader: @unchecked Sendable {

    private struct Sample {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let date: Date
    }

    private var previous: Sample?

    func read() -> (uploadPerSec: Double?, downloadPerSec: Double?) {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let addressList = interfacePointer else {
            return (nil, nil)
        }
        defer { freeifaddrs(interfacePointer) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

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
            bytesIn += UInt64(data.ifi_ibytes)
            bytesOut += UInt64(data.ifi_obytes)
        }

        let now = Date()
        defer { previous = Sample(bytesIn: bytesIn, bytesOut: bytesOut, date: now) }

        guard let previous, now > previous.date else { return (nil, nil) }
        let elapsed = now.timeIntervalSince(previous.date)
        guard elapsed > 0 else { return (nil, nil) }

        let upload = Self.rate(new: bytesOut, old: previous.bytesOut, elapsed: elapsed)
        let download = Self.rate(new: bytesIn, old: previous.bytesIn, elapsed: elapsed)
        return (upload, download)
    }

    private static func rate(new: UInt64, old: UInt64, elapsed: TimeInterval) -> Double? {
        guard new >= old else { return nil } // counter reset / wrap
        return Double(new - old) / elapsed
    }

    private static func isTrackedInterface(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let ignoredPrefixes = ["lo", "awdl", "llw", "utun", "ipsec", "gif", "stf"]
        return !ignoredPrefixes.contains { name.hasPrefix($0) }
    }
}