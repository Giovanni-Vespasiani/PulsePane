import Foundation
import CoreWLAN
import os

/// Passive network link quality assessment using CoreWLAN.
///
/// Uses only passive, non-privileged APIs to assess Wi-Fi link quality.
/// No active probing, no external requests, no elevated privileges.
final class NetworkQualityReader: @unchecked Sendable {

    /// Network quality classification.
    enum Quality: String, Sendable {
        case excellent
        case good
        case fair
        case poor
        case unknown
        case unsupported // Ethernet or no Wi-Fi interface
    }

    /// Snapshot of network quality at a point in time.
    struct Snapshot: Sendable {
        let quality: Quality
        let rssi: Int?           // dBm, negative (e.g., -45)
        let noise: Int?          // dBm, negative (e.g., -95)
        let snr: Int?            // dB, positive (e.g., 50)
        let txRate: Double?      // Mbps
        let interfaceName: String?
        let timestamp: Date
    }

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "network-quality")

    func snapshot() -> Snapshot {
        guard let interface = CWWiFiClient.shared().interface() else {
            logger.debug("NetworkQuality: no Wi-Fi interface")
            return Snapshot(quality: .unsupported, rssi: nil, noise: nil, snr: nil, txRate: nil, interfaceName: nil, timestamp: Date())
        }

        let interfaceName = interface.interfaceName ?? "unknown"

        // RSSI (signal strength)
        let rssi = interface.rssiValue()

        // Noise
        let noise = interface.noiseMeasurement()

        // SNR = RSSI - Noise (both in dBm, so result is in dB)
        let snr = rssi - noise

        // Transmit rate (Mbps)
        let txRate = interface.transmitRate()

        // Classify quality based on SNR primarily, with RSSI as secondary
        let quality = classifyQuality(rssi: rssi, snr: snr)

        logger.debug("NetworkQuality: interface=\(interfaceName) rssi=\(rssi) noise=\(noise) snr=\(snr ?? 0) txRate=\(txRate) quality=\(quality.rawValue)")

        return Snapshot(
            quality: quality,
            rssi: rssi,
            noise: noise,
            snr: snr,
            txRate: txRate,
            interfaceName: interfaceName,
            timestamp: Date()
        )
    }

    /// Classify network quality based on SNR and RSSI.
    ///
    /// Thresholds based on common Wi-Fi engineering guidelines:
    /// - Excellent: SNR ≥ 40 dB, RSSI > -50 dBm
    /// - Good: SNR ≥ 25 dB, RSSI > -65 dBm
    /// - Fair: SNR ≥ 15 dB, RSSI > -75 dBm
    /// - Poor: below Fair thresholds
    private func classifyQuality(rssi: Int?, snr: Int?) -> Quality {
        guard let snr = snr, let rssi = rssi else {
            // If we have RSSI but no SNR, use RSSI alone
            if let rssi = rssi {
                return classifyByRSSI(rssi)
            }
            return .unknown
        }

        // Primary classification by SNR
        switch snr {
        case 40...:
            return rssi > -50 ? .excellent : .good
        case 25..<40:
            return rssi > -65 ? .good : .fair
        case 15..<25:
            return .fair
        default:
            return .poor
        }
    }

    /// Fallback classification using only RSSI when SNR unavailable.
    private func classifyByRSSI(_ rssi: Int) -> Quality {
        switch rssi {
        case ..<(-80): return .poor
        case (-80)..<(-70): return .fair
        case (-70)..<(-60): return .good
        default: return .excellent
        }
    }
}