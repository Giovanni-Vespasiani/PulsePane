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
/// - Live observation of `NSApplication.didChangeScreenParametersNotification`
///   to recover position when Dock position/visibility or display configuration changes.
@MainActor
final class WindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private var appearanceObserver: NSKeyValueObservation?
    private var screenParamsObserver: ObserverToken?

    // Simple Sendable wrapper for the notification token
    private final class ObserverToken: @unchecked Sendable {
        let token: NSObjectProtocol
        init(_ token: NSObjectProtocol) { self.token = token }
    }

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
        // Phase 1 approved default: kCGDesktopIconWindowLevel + 2 (native widget layer)
        let defaultLevel = Int(CGWindowLevelForKey(.desktopIconWindow)) + 2
        var rawLevel = defaultLevel
        if let env = ProcessInfo.processInfo.environment["MP_WINDOW_LEVEL"],
           let value = Int(env) {
            rawLevel = value
        }
        window.level = NSWindow.Level(rawValue: rawLevel)

        // collectionBehavior variants for Phase 1 experiments (CB-001).
        // MP_BEHAVIOR: "A" (v2.4 current), "B" (Phase 1 approved, minus .transient), "C" (minus .fullScreenNone), "D" (minimal)
        // Phase 1 approved default: Variant B
        let defaultBehavior: NSWindow.CollectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
        var collectionBehavior = defaultBehavior
        if let env = ProcessInfo.processInfo.environment["MP_BEHAVIOR"] {
            switch env {
            case "A":
                collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenNone, .transient]
            case "B":
                collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
            case "C":
                collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle, .transient]
            case "D":
                collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
            default:
                collectionBehavior = defaultBehavior
            }
        }
        window.collectionBehavior = collectionBehavior
        window.title = "PulsePane"

        super.init()

        // Observe system appearance changes for live Light/Dark switching
        observeAppearanceChanges()

        // Observe display / Dock / screen parameter changes
        observeScreenParametersChanges()

        // Perform one-time legacy preference migration before restoring frame.
        migrateLegacyPreferencesIfNeeded()

        log("level rawValue = \(rawLevel) (default: \(defaultLevel), desktopIcon: \(Int(CGWindowLevelForKey(.desktopIconWindow))))")

        window.delegate = self
        window.contentView = RoundedHostingView(rootView: contentView, cornerRadius: 28)
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

    // MARK: - Appearance observation

    private func observeAppearanceChanges() {
        // Observe effective appearance changes for live Light/Dark switching
        appearanceObserver = window.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.updateAppearance()
        }

        // Observe accessibility settings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @MainActor
    private func updateAppearance() {
        // Widget follows system appearance automatically (no forced dark mode)
        // Background/material is handled by SwiftUI views via semantic colors
        log("appearance updated: \(window.effectiveAppearance.name.rawValue)")
    }

    @objc private func accessibilitySettingsChanged() {
        updateAppearance()
        log("accessibility settings changed")
    }

    // MARK: - Screen parameters observation

    private func observeScreenParametersChanges() {
        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChange()
        }
        screenParamsObserver = ObserverToken(token)
    }

    @MainActor
    private func handleScreenParametersChange() {
        log("screen parameters changed — revalidating window frame")
        // If current frame is no longer valid (e.g., Dock moved, display removed),
        // recover a valid frame preserving the user's intent as much as possible.
        if !DesktopGeometry.isValidRect(window.frame) {
            let recovered = DesktopGeometry.recoverFrame(window.frame, defaultSize: Self.defaultSize)
            if !NSEqualRects(recovered, window.frame) {
                log("frame invalid → recovered to \(NSStringFromRect(recovered))")
                window.setFrame(recovered, display: true, animate: true)
                persistFrame()
            }
        }
    }

    deinit {
        appearanceObserver?.invalidate()
        if let wrapper = screenParamsObserver {
            DispatchQueue.main.sync {
                NotificationCenter.default.removeObserver(wrapper.token)
            }
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Position persistence

    /// v2 default window size (fixed by content; the panel is 340 wide).
    static let defaultSize = NSSize(width: 340, height: 430)

    /// Version tag written into the persisted frame string so a saved v1 frame
    /// (320-wide panel, shorter) is not reused for the taller v2 layout. On v2
    /// launch we always apply `defaultSize`; the saved origin is still used so
    /// the user's placement survives.
    private static let frameVersion = "v2"
    private static let frameKey = "PulsePane.windowFrame"
    private static let legacyFrameKey = "MacPerformance.windowFrame"
    private static let migrationVersionKey = "PulsePane.migrationVersion"

    /// Performs one-time migration from legacy MacPerformance preferences.
    /// Runs on first launch with new bundle identifier / app name.
    private func migrateLegacyPreferencesIfNeeded() {
        let defaults = UserDefaults.standard

        // Check if migration already completed
        let currentMigrationVersion = 1
        let migratedVersion = defaults.integer(forKey: Self.migrationVersionKey)
        if migratedVersion >= currentMigrationVersion {
            return
        }

        // Read legacy frame if it exists
        if let legacyFrameString = defaults.string(forKey: Self.legacyFrameKey) {
            // Only migrate if no valid PulsePane frame exists yet
            if defaults.string(forKey: Self.frameKey) == nil {
                // Validate legacy frame format (should be "v2|{x, y, w, h}")
                let parts = legacyFrameString.split(separator: "|", maxSplits: 1)
                if parts.count == 2, parts[0] == Self.frameVersion {
                    let rect = NSRectFromString(String(parts[1]))
                    // Validate rect is reasonable (not empty, not absurdly large)
                    if !rect.isNull, rect.width > 0, rect.height > 0,
                       rect.width < 10000, rect.height < 10000 {
                        // Write to new key with v2 version prefix
                        let newFrameString = "\(Self.frameVersion)|\(NSStringFromRect(rect))"
                        defaults.set(newFrameString, forKey: Self.frameKey)
                        log("migrated legacy window frame: \(legacyFrameString) → \(newFrameString)")
                    }
                }
            }
        }

        // Mark migration complete
        defaults.set(currentMigrationVersion, forKey: Self.migrationVersionKey)
    }

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
                return DesktopGeometry.isValidRect(sized) ? sized : defaultFrame()
            }
        }
        // v1 frame (unversioned) or invalid → default origin with v2 size.
        return defaultFrame()
    }

    private func defaultFrame() -> NSRect {
        return DesktopGeometry.defaultFrame(defaultSize: Self.defaultSize)
    }

    /// Clamps/validates: a restored frame only counts if it overlaps a visible
    /// screen enough to remain usable (e.g. after a monitor was unplugged).
    private func isOnAnyVisibleScreen(_ rect: NSRect) -> Bool {
        return DesktopGeometry.isValidRect(rect)
    }

    // MARK: - Window drag handling with edge snapping

    func windowDidMove(_ notification: Notification) {
        // Apply edge snapping when drag ends
        let snappedFrame = DesktopGeometry.snapToEdges(window.frame)
        if !NSEqualRects(snappedFrame, window.frame) {
            window.setFrame(snappedFrame, display: true, animate: true)
        }
        persistFrame()
    }

    // MARK: - Quit affordance (no Dock icon, so a right-click menu)

    private var quitMenu: NSMenu {
        let menu = NSMenu()
        let quit = NSMenuItem(
            title: "Quit PulsePane",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}