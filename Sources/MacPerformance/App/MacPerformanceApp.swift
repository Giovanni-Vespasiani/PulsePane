import SwiftUI
import Darwin

@main
struct MacPerformanceApp: App {
    init() {
        // Unbuffer stdout so `print`/debug output is visible immediately
        // when run from a terminal (e.g. MP_DEBUG=1).
        setvbuf(stdout, nil, _IONBF, 0)
    }

    var body: some Scene {
        WindowGroup {
            PerformanceWidgetView()
        }
    }
}