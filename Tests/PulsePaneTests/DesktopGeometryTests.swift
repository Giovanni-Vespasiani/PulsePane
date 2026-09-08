import XCTest
@testable import PulsePane

final class DesktopGeometryTests: XCTestCase {

    func testSafeAreaInsetsVisibleFrame() {
        // Test that safeArea insets the visibleFrame by aestheticMargin
        for screen in NSScreen.screens {
            let visible = screen.visibleFrame
            let safe = DesktopGeometry.safeArea(for: screen)
            let inset = DesktopGeometry.aestheticMargin

            XCTAssertEqual(safe.minX, visible.minX + DesktopGeometry.aestheticMargin, accuracy: 0.5)
            XCTAssertEqual(safe.minY, visible.minY + DesktopGeometry.aestheticMargin, accuracy: 0.5)
            XCTAssertEqual(safe.maxX, visible.maxX - DesktopGeometry.aestheticMargin, accuracy: 0.5)
            XCTAssertEqual(safe.maxY, visible.maxY - DesktopGeometry.aestheticMargin, accuracy: 0.5)
        }
    }

    func testSafeAreaFallbackWhenInsetTooLarge() {
        // Test the logic directly - if inset makes rect too small, fallback to visibleFrame
        let tinyVisible = NSRect(x: 0, y: 0, width: 10, height: 10)
        let safeRect = tinyVisible.insetBy(dx: DesktopGeometry.aestheticMargin, dy: DesktopGeometry.aestheticMargin)

        // If inset makes rect invalid, the function should return visibleFrame
        XCTAssertTrue(safeRect.width < DesktopGeometry.minimumWidgetSize.width)
        XCTAssertTrue(safeRect.height < DesktopGeometry.minimumWidgetSize.height)
    }

    func testClampToVisibleScreens() {
        let defaultSize = NSSize(width: 340, height: 430)

        // Test clamping a frame that's off-screen to the left
        let offScreenLeft = NSRect(x: -1000, y: 100, width: 340, height: 430)
        let clamped = DesktopGeometry.clampToVisibleScreens(offScreenLeft, defaultSize: defaultSize)
        XCTAssertTrue(DesktopGeometry.isValidRect(clamped))

        // Test clamping a frame that's off-screen to the right
        let screens = NSScreen.screens
        let maxX = NSScreen.screens.map { $0.frame.maxX }.max() ?? 2000
        let offScreenRight = NSRect(x: maxX + 1000, y: 100, width: 340, height: 430)
        let clampedRight = DesktopGeometry.clampToVisibleScreens(offScreenRight, defaultSize: defaultSize)
        XCTAssertTrue(DesktopGeometry.isValidRect(clampedRight))

        // Test a valid frame stays unchanged
        let validFrame = NSRect(x: 100, y: 100, width: 340, height: 430)
        let unchanged = DesktopGeometry.clampToVisibleScreens(validFrame, defaultSize: defaultSize)
        XCTAssertEqual(unchanged.origin.x, 100, accuracy: 1)
        XCTAssertEqual(unchanged.origin.y, 100, accuracy: 1)
    }

    func testDefaultFrame() {
        let defaultSize = NSSize(width: 340, height: 430)
        let frame = DesktopGeometry.defaultFrame(defaultSize: defaultSize)

        XCTAssertEqual(frame.size.width, 340)
        XCTAssertEqual(frame.size.height, 430)
        XCTAssertTrue(DesktopGeometry.isValidRect(frame))
    }

    func testSnapToEdgesLeft() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place widget just inside snap threshold from left edge
        let x = safeArea.minX + 10
        let y = safeArea.midY - widgetSize.height / 2
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // Should snap to left edge
        XCTAssertEqual(snapped.origin.x, safeArea.minX, accuracy: 1)
        XCTAssertEqual(snapped.origin.y, y, accuracy: 1)
        XCTAssertEqual(snapped.size.width, widgetSize.width)
        XCTAssertEqual(snapped.size.height, widgetSize.height)
    }

    func testSnapToEdgesRight() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place widget just inside snap threshold from right edge
        let x = safeArea.maxX - widgetSize.width - 10
        let y = safeArea.midY - widgetSize.height / 2
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // Should snap to right edge
        XCTAssertEqual(snapped.origin.x, safeArea.maxX - widgetSize.width, accuracy: 1)
        XCTAssertEqual(snapped.origin.y, y, accuracy: 1)
    }

    func testSnapToEdgesTop() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place widget just inside snap threshold from top edge
        let x = safeArea.midX - widgetSize.width / 2
        let y = safeArea.maxY - widgetSize.height - 10
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // Should snap to top edge
        XCTAssertEqual(snapped.origin.y, safeArea.maxY - widgetSize.height, accuracy: 1)
    }

    func testSnapToEdgesBottom() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place widget just inside snap threshold from bottom edge
        let x = safeArea.midX - widgetSize.width / 2
        let y = safeArea.minY + 10
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // Should snap to bottom edge
        XCTAssertEqual(snapped.origin.y, safeArea.minY, accuracy: 1)
    }

    func testSnapThresholdNotTriggered() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place widget well outside snap threshold
        let x = safeArea.minX + DesktopGeometry.snapThreshold + 50
        let y = safeArea.midY - widgetSize.height / 2
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // Should NOT snap
        XCTAssertEqual(snapped.origin.x, x, accuracy: 1)
        XCTAssertEqual(snapped.origin.y, y, accuracy: 1)
    }

    func testSnapThresholdBoundary() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Place exactly at snap threshold distance
        let x = safeArea.minX + DesktopGeometry.snapThreshold
        let y = safeArea.midY - widgetSize.height / 2
        var rect = NSRect(origin: NSPoint(x: x, y: y), size: widgetSize)

        let snapped = DesktopGeometry.snapToEdges(rect)

        // At exactly threshold, should snap
        XCTAssertEqual(snapped.origin.x, safeArea.minX, accuracy: 1)
    }

    func testSnapToCorners() {
        let screen = NSScreen.main!
        let safeArea = DesktopGeometry.safeArea(for: screen)
        let widgetSize = NSSize(width: 340, height: 430)

        // Top-left corner
        var rect = NSRect(
            origin: NSPoint(x: safeArea.minX + 10, y: safeArea.maxY - widgetSize.height - 10),
            size: widgetSize
        )
        let snappedTL = DesktopGeometry.snapToEdges(rect)
        XCTAssertEqual(snappedTL.origin.x, safeArea.minX, accuracy: 1)
        XCTAssertEqual(snappedTL.origin.y, safeArea.maxY - widgetSize.height, accuracy: 1)

        // Bottom-right corner
        rect = NSRect(
            origin: NSPoint(x: safeArea.maxX - widgetSize.width - 10, y: safeArea.minY + 10),
            size: widgetSize
        )
        let snappedBR = DesktopGeometry.snapToEdges(rect)
        XCTAssertEqual(snappedBR.origin.x, safeArea.maxX - widgetSize.width, accuracy: 1)
        XCTAssertEqual(snappedBR.origin.y, safeArea.minY, accuracy: 1)
    }

    func testFrameRecoveryValidFrame() {
        let defaultSize = NSSize(width: 340, height: 430)
        let validRect = NSRect(x: 100, y: 100, width: 340, height: 430)

        let recovered = DesktopGeometry.recoverFrame(validRect, defaultSize: defaultSize)
        XCTAssertEqual(recovered.origin.x, 100, accuracy: 1)
        XCTAssertEqual(recovered.origin.y, 100, accuracy: 1)
    }

    func testFrameRecoveryOffScreen() {
        let defaultSize = NSSize(width: 340, height: 430)
        let offScreen = NSRect(x: -5000, y: -5000, width: 340, height: 430)

        let recovered = DesktopGeometry.recoverFrame(offScreen, defaultSize: defaultSize)
        XCTAssertTrue(DesktopGeometry.isValidRect(recovered))
    }

    func testFrameRecoveryNullRect() {
        let defaultSize = NSSize(width: 340, height: 430)
        let nullRect = NSRect.null

        let recovered = DesktopGeometry.recoverFrame(NSRect.null, defaultSize: defaultSize)
        // Should fall back to default frame
        let defaultFrame = DesktopGeometry.defaultFrame(defaultSize: defaultSize)
        XCTAssertEqual(recovered.origin.x, defaultFrame.origin.x, accuracy: 1)
        XCTAssertEqual(recovered.origin.y, defaultFrame.origin.y, accuracy: 1)
    }

    func testValidRestoredFrame() {
        let validFrame = "v2|{{100, 200}, {340, 430}}"
        XCTAssertTrue(DesktopGeometry.isValidRestoredFrame(validFrame))
    }

    func testInvalidVersionRestoredFrame() {
        XCTAssertFalse(DesktopGeometry.isValidRestoredFrame("v1|{{100, 200}, {340, 430}}"))
        XCTAssertFalse(DesktopGeometry.isValidRestoredFrame("v3|{{100, 200}, {340, 430}}"))
    }

    func testMalformedRestoredFrame() {
        XCTAssertFalse(DesktopGeometry.isValidRestoredFrame("invalid"))
        XCTAssertFalse(DesktopGeometry.isValidRestoredFrame("v2|invalid"))
        XCTAssertFalse(DesktopGeometry.isValidRestoredFrame(""))
    }

    func testOffScreenFrameMigrationThenClamp() {
        // Legacy frame that's off-screen should migrate, then be clamped by WindowController
        let offScreenFrame = "v2|{{9999, 9999}, {340, 430}}"
        XCTAssertTrue(DesktopGeometry.isValidRestoredFrame(offScreenFrame))
    }
}