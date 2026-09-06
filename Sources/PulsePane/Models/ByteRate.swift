import Foundation

/// Small formatters for rates / power used by the v2 UI. Kept in one place so
/// every row formats identically (no layout shifting thanks to monospacedDigit
/// in the views).
enum ByteRate {

    /// 123 B/s → "123 B/s", 1.5 MB → "1.5 MB/s", 2 GB+ → "2.00 GB/s".
    static func string(bytesPerSec: Double, fractionDigits: Int = 1) -> String {
        let value = max(bytesPerSec, 0)
        switch value {
        case ..<1024:
            return String(format: "%.0f B/s", value)
        case ..<(1024 * 1024):
            return String(format: "%.0f KB/s", value / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.\(fractionDigits)f MB/s", value / (1024 * 1024))
        default:
            return String(format: "%.2f GB/s", value / (1024 * 1024 * 1024))
        }
    }

    /// Watts with one decimal: 8.4
    static func watts(_ watts: Double) -> String {
        String(format: "%.1f W", watts)
    }

    static func temperature(_ celsius: Double) -> String {
        String(format: "%.0f°C", celsius)
    }
}