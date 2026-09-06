import Foundation
import AppKit
import os

/// Handles macOS sleep/wake notifications and notifies readers to reset their baselines.
///
/// When the system sleeps and wakes, delta-based counters (CPU, Network, Disk)
/// would compute misleading deltas across the sleep interval. This handler
/// listens for sleep/wake notifications and triggers baseline resets on all
/// readers that need it.
///
/// Usage:
/// ```swift
/// let wakeHandler = WakeHandler()
/// wakeHandler.register(cpuReader)   // if CPUReader conforms to BaselineResettable
/// wakeHandler.register(networkReader)
/// wakeHandler.register(diskReader)
/// wakeHandler.start()
/// ```
final class WakeHandler {

    // MARK: - Protocol

    protocol BaselineResettable: AnyObject {
        func resetBaselines()
    }

    // MARK: - State

    private let logger = Logger(subsystem: "com.github.Giovanni-Vespasiani.PulsePane", category: "wake")
    private weak var cpuReader: (any BaselineResettable)?
    private weak var networkReader: (any BaselineResettable)?
    private weak var diskReader: (any BaselineResettable)?
    private weak var gpuReader: (any BaselineResettable)?

    // MARK: - Registration

    func register(_ reader: any BaselineResettable) {
        switch reader {
        case let r as CPUReader: cpuReader = r
        case let r as NetworkReader: networkReader = r
        case let r as DiskReader: diskReader = r
        case let r as GPUReader: gpuReader = r
        default: break
        }
    }

    // MARK: - Lifecycle

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        logger.info("WakeHandler: started listening for sleep/wake notifications")
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        logger.info("WakeHandler: stopped")
    }

    // MARK: - Notifications

    @objc private func willSleep(_ notification: Notification) {
        logger.info("WakeHandler: system will sleep")
        // Optional: could do pre-sleep cleanup here
    }

    @objc private func didWake(_ notification: Notification) {
        logger.info("WakeHandler: system did wake — resetting baselines")
        cpuReader?.resetBaselines()
        networkReader?.resetBaselines()
        diskReader?.resetBaselines()
        gpuReader?.resetBaselines()
        logger.info("WakeHandler: all baselines reset")
    }
}