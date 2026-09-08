import Foundation
import AppKit

/// Pure geometry utilities for desktop widget positioning.
///
/// All functions are pure and testable without hardware dependencies.
enum DesktopGeometry {

    /// Aesthetic margin from screen edges (in points).
    /// Tuned to match macOS desktop widget feel.
    static let aestheticMargin: CGFloat = 16

    /// Snap threshold distance (in points).
    /// When widget edge is within this distance of screen edge, it snaps.
    static let snapThreshold: CGFloat = 20

    /// Minimum widget size for validation.
    static let minimumWidgetSize = NSSize(width: 200, height: 150)

    /// Computes the safe area for widget placement on a given screen.
    ///
    /// The safe area is the screen's `visibleFrame` inset by `aestheticMargin`
    /// on all sides, ensuring the widget stays clear of Dock, menu bar, and edges.
    ///
    /// - Parameter screen: The screen to compute safe area for.
    /// - Returns: The safe area rect, or the screen's visibleFrame if inset results in empty rect.
    static func safeArea(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let inset = aestheticMargin
        let safeRect = visible.insetBy(dx: inset, dy: inset)

        // If inset makes rect invalid, fall back to visibleFrame
        if safeRect.width < minimumWidgetSize.width || safeRect.height < minimumWidgetSize.height {
            return visible
        }
        return safeRect
    }

    /// Computes the union of all visible screen frames.
    ///
    /// Used for multi-display clamping and validation.
    static func unionOfVisibleFrames() -> NSRect {
        var union = NSRect.null
        for screen in NSScreen.screens {
            union = union.union(screen.frame)
        }
        return union
    }

    /// Computes the union of all visible screen frames (safe areas).
    static func unionOfVisibleSafeAreas() -> NSRect {
        var union = NSRect.null
        for screen in NSScreen.screens {
            union = union.union(safeArea(for: screen))
        }
        return union
    }

    /// Clamps a rectangle to be within the union of all visible safe areas.
    ///
    /// If the rectangle is entirely outside all safe areas, returns a centered
    /// default frame on the main screen.
    ///
    /// - Parameters:
    ///   - rect: The rectangle to clamp.
    ///   - defaultSize: The size to use if clamping results in invalid rect.
    /// - Returns: A clamped rectangle guaranteed to be on-screen.
    static func clampToVisibleScreens(_ rect: NSRect, defaultSize: NSSize) -> NSRect {
        let union = unionOfVisibleSafeAreas()
        if union.isNull { return defaultFrame(defaultSize: defaultSize) }

        let intersection = rect.intersection(union)
        if intersection.isNull {
            return defaultFrame(defaultSize: defaultSize)
        }

        // If intersection is too small, fall back to default
        if intersection.width < minimumWidgetSize.width || intersection.height < minimumWidgetSize.height {
            return defaultFrame(defaultSize: defaultSize)
        }

        // Clamp origin to keep widget fully within union
        var clamped = intersection
        let maxX = union.maxX - defaultSize.width
        let maxY = union.maxY - defaultSize.height
        clamped.origin.x = min(max(intersection.origin.x, union.minX), maxX)
        clamped.origin.y = min(max(intersection.origin.y, union.minY), maxY)

        return clamped
    }

    /// Returns a default centered frame on the main screen.
    static func defaultFrame(defaultSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(origin: NSPoint(x: 100, y: 100), size: defaultSize)
        }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - defaultSize.width / 2,
            y: visible.midY - defaultSize.height / 2
        )
        return NSRect(origin: origin, size: defaultSize)
    }

    /// Snaps a rectangle's origin to screen edges if within snap threshold.
    ///
    /// Only snaps the origin (keeps size unchanged). Snaps to the nearest
    /// screen edge within the safe area of the screen containing the rect's center.
    ///
    /// - Parameters:
    ///   - rect: The rectangle to snap (origin will be modified, size preserved).
    ///   - screens: The screens to snap against (defaults to all screens).
    /// - Returns: A new rectangle with snapped origin.
    static func snapToEdges(_ rect: NSRect, screens: [NSScreen] = NSScreen.screens) -> NSRect {
        // Find the screen containing the rect's center
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let containingScreen = screens.first { NSPointInRect(center, $0.frame) } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = containingScreen else { return rect }

        let safeArea = safeArea(for: screen)
        var origin = rect.origin
        let snapDistance = snapThreshold

        // Snap to left edge
        if abs(origin.x - safeArea.minX) <= snapDistance {
            origin.x = safeArea.minX
        }
        // Snap to right edge
        else if abs((origin.x + rect.width) - safeArea.maxX) <= snapDistance {
            origin.x = safeArea.maxX - rect.width
        }

        // Snap to top edge (screen coordinates: top is maxY)
        if abs((origin.y + rect.height) - safeArea.maxY) <= snapDistance {
            origin.y = safeArea.maxY - rect.height
        }
        // Snap to bottom edge
        else if abs(origin.y - safeArea.minY) <= snapDistance {
            origin.y = safeArea.minY
        }

        return NSRect(origin: origin, size: rect.size)
    }

    /// Computes the nearest valid position for a frame that may be off-screen.
    ///
    /// Tries to preserve the original position if valid, otherwise finds
    /// the nearest valid position within safe areas.
    ///
    /// - Parameters:
    ///   - rect: The original frame to validate/recover.
    ///   - defaultSize: The default widget size.
    /// - Returns: A valid frame guaranteed to be on-screen.
    static func recoverFrame(_ rect: NSRect, defaultSize: NSSize) -> NSRect {
        // If already valid, return as-is
        if isValidRect(rect) {
            return rect
        }

        // Try clamping to visible screens
        let clamped = clampToVisibleScreens(rect, defaultSize: defaultSize)
        if isValidRect(clamped) {
            return clamped
        }

        // Fallback to default
        return defaultFrame(defaultSize: defaultSize)
    }

    /// Checks if a rect is valid (non-null, positive size, reasonable bounds).
    static func isValidRect(_ rect: NSRect) -> Bool {
        guard !rect.isNull,
              rect.width > 0, rect.height > 0,
              rect.width < 10000, rect.height < 10000 else { return false }

        let union = unionOfVisibleFrames()
        return !rect.intersection(union).isNull
    }

    /// Validates only the frame format (version prefix, rect format, reasonable bounds).
    /// Does NOT check if the frame is on-screen; that is handled by WindowController.
    static func isValidRestoredFrame(_ frameString: String) -> Bool {
        let parts = frameString.split(separator: "|", maxSplits: 1)
        guard parts.count == 2, parts[0] == "v2" else { return false }

        let rect = NSRectFromString(String(parts[1]))
        guard !rect.isNull,
              rect.width > 0, rect.height > 0,
              rect.width < 10000, rect.height < 10000 else { return false }

        return true
    }
}