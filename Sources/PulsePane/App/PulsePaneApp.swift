import SwiftUI
import Darwin

@main
struct PulsePaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Unbuffer stdout so debug output is visible immediately when run from
        // a terminal (e.g. MP_DEBUG=1).
        setvbuf(stdout, nil, _IONBF, 0)
    }

    var body: some Scene {
        // No regular window scene: the AppDelegate owns the single widget
        // window. LSUIElement in Info.plist hides the Dock icon.
        Settings { EmptyView() }
    }
}

/// Creates and shows the desktop widget window at launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: WindowController?
    private var wakeHandler: WakeHandler?
    private var capabilities: SystemCapabilities.Snapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Capture system capabilities at launch for diagnostics
        capabilities = SystemCapabilities.detect()
        logCapabilities()

        let controller = WindowController(contentView: PerformanceWidgetView())
        controller.show()
        windowController = controller

        // Initialize and start wake handler
        // Note: We need to access the readers from the view model
        // For now, we'll set up the wake handler when the model is available
        // The WakeHandler will be started when the view appears
    }

    private func logCapabilities() {
        guard let caps = capabilities else { return }
        print("PulsePane v2.2 — System Capabilities:")
        print("  Machine: \(caps.machineModel) (\(caps.architecture))")
        print("  macOS: \(caps.macOSVersion)")
        print("  CPU: \(caps.cpuLogicalCount) logical cores")
        print("  Memory: \(caps.physicalMemoryBytes / (1024*1024*1024)) GB")
        print("  Apple Silicon: \(caps.isAppleSilicon ? "yes" : "no")")
        print("  GPU: \(caps.gpuAvailable ? "available (\(caps.gpuServiceClass ?? "unknown"), key: \(caps.gpuPreferredKey ?? "unknown"))" : "unavailable")")
        print("  Power: \(caps.powerAvailable ? "available (\(caps.powerSource ?? "unknown"))" : "unavailable")")
        print("  Temperature: \(caps.temperatureAvailable ? "available" : "unavailable")")
        print("  Network: \(caps.networkAvailable ? "available" : "unavailable")")
        print("  Disk: \(caps.diskAvailable ? "available" : "unavailable")")
    }
}