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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = WindowController(contentView: PerformanceWidgetView())
        controller.show()
        windowController = controller
    }
}