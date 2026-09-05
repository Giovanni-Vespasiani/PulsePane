import AppKit
import SwiftUI

/// Owns the single frameless widget window.
///
/// Behaviour chosen empirically for the "desktop widget" requirement
/// (see DECISIONS D-006):
/// - `.borderless` style mask → no title bar, no traffic lights, no chrome.
/// - `level = .desktop` → sits with the desktop, *below* normal app windows
///   (they always appear in front; we are NOT always-on-top), above wallpaper.
/// - `isMovableByWindowBackground = true` → drag by clicking anywhere.
/// - `collectionBehavior = [.stationary]` → stays put on its Space.
/// - Position saved to/restored from `UserDefaults`, clamped to a visible
///   screen on launch (handles display changes / unplugged monitors).
@MainActor
final class WindowController: NSObject, NSWindowDelegate {
    let window: NSWindow

    private static let frameKey = "MacPerformance.windowFrame"
    static let defaultSize = NSSize(width: 320, height: 210)

    init(contentView: some View) {
        let contentRect = NSRect(origin: .zero, size: Self.defaultSize)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Desktop element, not a normal window. kCGDesktopWindowLevel puts us
        // with the desktop, below normal app windows (see DECISIONS D-006).
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopWindow))
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.stationary]
        window.title = "MacPerformance"

        super.init()

        window.delegate = self
        window.contentView = NSHostingView(rootView: contentView)
        window.contentView?.menu = quitMenu
    }

    // MARK: - Showing

    func show() {
        window.setFrame(restoredFrame(), display: true)
        // orderFrontRegardless instead of makeKeyAndOrderFront so we do not
        // steal the keyboard focus / activate the app (desktop widget).
        window.orderFrontRegardless()
    }

    // MARK: - Position persistence

    /// Persists the current frame as an NSStringFromRect string.
    private func persistFrame() {
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.frameKey)
    }

    /// Returns the saved frame if it is still on a visible screen, otherwise a
    /// sensible default (centered on the main screen).
    private func restoredFrame() -> NSRect {
        guard let saved = UserDefaults.standard.string(forKey: Self.frameKey) else {
            return defaultFrame()
        }
        let rect = NSRectFromString(saved)
        return isOnAnyVisibleScreen(rect) ? rect : defaultFrame()
    }

    private func defaultFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: NSPoint(x: 100, y: 100), size: Self.defaultSize)
        }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - Self.defaultSize.width / 2,
            y: visible.midY - Self.defaultSize.height / 2
        )
        return NSRect(origin: origin, size: Self.defaultSize)
    }

    /// Clamps/validates: a restored frame only counts if it overlaps a visible
    /// screen enough to remain usable (e.g. after a monitor was unplugged).
    private func isOnAnyVisibleScreen(_ rect: NSRect) -> Bool {
        var union = NSRect.null
        for screen in NSScreen.screens {
            union = union.union(screen.frame)
        }
        if union.isNull { return false }
        let intersection = rect.intersection(union)
        if intersection.isNull { return false }
        return intersection.width * intersection.height >= 9000
    }

    // MARK: - Quit affordance (no Dock icon, so a right-click menu)

    private var quitMenu: NSMenu {
        let menu = NSMenu()
        let quit = NSMenuItem(
            title: "Quit MacPerformance",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        persistFrame()
    }
}