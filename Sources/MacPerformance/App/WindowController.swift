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

    init(contentView: some View) {
        let contentRect = NSRect(origin: .zero, size: Self.defaultSize)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Window level (see DECISIONS D-006).
        // kCGDesktopWindowLevel ends up BELOW Finder's full-screen desktop
        // window (kCGDesktopIconWindowLevel) → widget hidden. We render just
        // ABOVE the desktop icons layer and below kCGNormalWindowLevel (0).
        // MP_WINDOW_LEVEL env var overrides the raw level for A/B testing.
        let defaultLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        var rawLevel = defaultLevel
        if let env = ProcessInfo.processInfo.environment["MP_WINDOW_LEVEL"],
           let value = Int(env) {
            rawLevel = value
        }
        window.level = NSWindow.Level(rawValue: rawLevel)

        // Always render the widget in dark, regardless of system appearance.
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        window.title = "MacPerformance"

        super.init()

        log("level rawValue = \(rawLevel) (default: \(defaultLevel), desktopIcon: \(Int(CGWindowLevelForKey(.desktopIconWindow))))")

        window.delegate = self
        window.contentView = NSHostingView(rootView: contentView)
        window.contentView?.menu = quitMenu
    }

    // MARK: - Showing

    func show() {
        let saved = UserDefaults.standard.string(forKey: Self.frameKey)
        let restored = restoredFrame()
        log("persisted frame=\(saved ?? "nil") → restored=\(NSStringFromRect(restored))")
        window.setFrame(restored, display: true)
        // orderFrontRegardless instead of makeKeyAndOrderFront so we do not
        // steal the keyboard focus / activate the app (desktop widget).
        window.orderFrontRegardless()
        log("window.frame=\(NSStringFromRect(window.frame))")
        log("window.level=\(window.level.rawValue)")
        log("window.isVisible=\(window.isVisible)")
        log("window.occlusionState=\(window.occlusionState)")

        if let screen = window.screen {
            log("window.screen.frame=\(NSStringFromRect(screen.frame))")
        } else {
            log("window.screen=nil")
        }
    }

    private func log(_ message: String) {
        guard ProcessInfo.processInfo.environment["MP_DEBUG"] == "1" else { return }
        FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    }

    // MARK: - Position persistence

    /// v2 default window size (fixed by content; the panel is 340 wide).
    static let defaultSize = NSSize(width: 340, height: 430)

    /// Version tag written into the persisted frame string so a saved v1 frame
    /// (320-wide panel, shorter) is not reused for the taller v2 layout. On v2
    /// launch we always apply `defaultSize`; the saved origin is still used so
    /// the user's placement survives.
    private static let frameVersion = "v2"
    private static let frameKey = "MacPerformance.windowFrame"

    /// Persists the current frame as an NSStringFromRect string.
    private func persistFrame() {
        let s = NSStringFromRect(window.frame)
        UserDefaults.standard.set("\(Self.frameVersion)|\(s)", forKey: Self.frameKey)
    }

    /// Returns the saved location (size replaced by v2 default) if it is still
    /// on a visible screen, otherwise a sensible default (centered).
    private func restoredFrame() -> NSRect {
        let saved = UserDefaults.standard.string(forKey: Self.frameKey)
        if let saved {
            let parts = saved.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == Self.frameVersion {
                let rect = NSRectFromString(String(parts[1]))
                let sized = NSRect(origin: rect.origin, size: Self.defaultSize)
                return isOnAnyVisibleScreen(sized) ? sized : defaultFrame()
            }
        }
        // v1 frame (unversioned) or invalid → default origin with v2 size.
        return defaultFrame()
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