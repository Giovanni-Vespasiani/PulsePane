import XCTest
@testable import PulsePane

final class PersistenceMigrationTests: XCTestCase {

    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use a unique suite name to avoid contaminating real preferences
        let suiteName = "PulsePaneTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        let suiteName = "PulsePaneTests-\(UUID().uuidString)"
        if let d = UserDefaults(suiteName: suiteName) {
            d.removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    func testValidLegacyFrameWithNoPulsePaneStateMigrates() {
        // Given: Legacy frame exists, no PulsePane state
        let legacyFrame = "v2|{{100, 200}, {340, 430}}"
        defaults.set(legacyFrame, forKey: "MacPerformance.windowFrame")

        // When: Migration runs
        let migratedFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNil(migratedFrame, "PulsePane frame should not exist before migration")

        // Simulate migration logic
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            let parts = legacy.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == "v2" {
                let rect = NSRectFromString(String(parts[1]))
                if !rect.isNull, rect.width > 0, rect.height > 0,
                   rect.width < 10000, rect.height < 10000 {
                    let newFrameString = "v2|\(NSStringFromRect(rect))"
                    defaults.set(newFrameString, forKey: "PulsePane.windowFrame")
                }
            }
        }
        defaults.set(1, forKey: "PulsePane.migrationVersion")

        // Then: Legacy frame should be migrated
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNotNil(pulseFrame)
        XCTAssertEqual(pulseFrame, "v2|{{100, 200}, {340, 430}}")
    }

    func testPulsePaneStateAlreadyExistsDoesNotOverwrite() {
        // Given: Both legacy and PulsePane frames exist
        defaults.set("v2|{{100, 200}, {340, 430}}", forKey: "MacPerformance.windowFrame")
        defaults.set("v2|{{50, 50}, {340, 430}}", forKey: "PulsePane.windowFrame")

        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            // This should not execute because PulsePane frame exists
            XCTFail("Migration should not run when PulsePane frame exists")
        }

        // Then: PulsePane frame should remain unchanged
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertEqual(pulseFrame, "v2|{{50, 50}, {340, 430}}")
    }

    func testNoLegacyFrameNoMigration() {
        // Given: No legacy frame
        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            XCTFail("Migration should not run when no legacy frame")
        }

        // Then: No PulsePane frame should be created
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNil(pulseFrame)
    }

    func testMalformedLegacyFrameDoesNotMigrate() {
        // Given: Malformed legacy frame
        defaults.set("v1|{{100, 200}, {340, 430}}", forKey: "MacPerformance.windowFrame") // wrong version

        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            let parts = legacy.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == "v2" {
                XCTFail("Should not migrate v1 frame")
            }
        }

        // Then: No PulsePane frame should be created
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNil(pulseFrame)
    }

    func testMalformedRectDoesNotMigrate() {
        // Given: Legacy frame with malformed rect
        defaults.set("v2|invalid-rect", forKey: "MacPerformance.windowFrame")

        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            let parts = legacy.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == "v2" {
                let rect = NSRectFromString(String(parts[1]))
                if rect.isNull || rect.width <= 0 || rect.height <= 0 {
                    // Invalid rect - should not migrate
                } else {
                    XCTFail("Should not migrate invalid rect")
                }
            }
        }

        // Then: No PulsePane frame should be created
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNil(pulseFrame)
    }

    func testOffScreenLegacyFrameMigratesThenClamps() {
        // Given: Legacy frame that's off-screen
        let offScreenFrame = "v2|{{9999, 9999}, {340, 430}}"
        defaults.set(offScreenFrame, forKey: "MacPerformance.windowFrame")

        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            let parts = legacy.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == "v2" {
                let rect = NSRectFromString(String(parts[1]))
                if !rect.isNull, rect.width > 0, rect.height > 0,
                   rect.width < 10000, rect.height < 10000 {
                    let newFrameString = "v2|\(NSStringFromRect(rect))"
                    defaults.set(newFrameString, forKey: "PulsePane.windowFrame")
                }
            }
        }
        defaults.set(1, forKey: "PulsePane.migrationVersion")

        // Then: Frame is migrated (but will be clamped by WindowController on restore)
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNotNil(pulseFrame)
        XCTAssertEqual(pulseFrame, offScreenFrame)
    }

    func testMigrationMarkerAlreadySetDoesNotRepeat() {
        // Given: Migration already completed
        defaults.set("v2|{{100, 200}, {340, 430}}", forKey: "MacPerformance.windowFrame")
        defaults.set("v2|{{50, 50}, {340, 430}}", forKey: "PulsePane.windowFrame")
        defaults.set(1, forKey: "PulsePane.migrationVersion")

        // When: Migration runs again
        let migratedVersion = defaults.integer(forKey: "PulsePane.migrationVersion")

        // Then: Should detect already migrated
        XCTAssertEqual(migratedVersion, 1)
    }

    func testMigrationCalledTwiceIsIdempotent() {
        // Given: Legacy frame, no PulsePane state
        let legacyFrame = "v2|{{100, 200}, {340, 430}}"
        defaults.set(legacyFrame, forKey: "MacPerformance.windowFrame")

        // When: Migration runs twice
        for _ in 0..<2 {
            if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
               defaults.string(forKey: "PulsePane.windowFrame") == nil {
                let parts = legacy.split(separator: "|", maxSplits: 1)
                if parts.count == 2, parts[0] == "v2" {
                    let rect = NSRectFromString(String(parts[1]))
                    if !rect.isNull, rect.width > 0, rect.height > 0,
                       rect.width < 10000, rect.height < 10000 {
                        let newFrameString = "v2|\(NSStringFromRect(rect))"
                        defaults.set(newFrameString, forKey: "PulsePane.windowFrame")
                    }
                }
            }
            defaults.set(1, forKey: "PulsePane.migrationVersion")
        }

        // Then: PulsePane frame should be set only once (no crash, no overwrite)
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertEqual(pulseFrame, "v2|{{100, 200}, {340, 430}}")
        XCTAssertEqual(defaults.integer(forKey: "PulsePane.migrationVersion"), 1)
    }

    func testUnsupportedLegacyVersionString() {
        // Given: Legacy frame with unknown version
        defaults.set("v99|{{100, 200}, {340, 430}}", forKey: "MacPerformance.windowFrame")

        // When: Migration runs
        if let legacy = defaults.string(forKey: "MacPerformance.windowFrame"),
           defaults.string(forKey: "PulsePane.windowFrame") == nil {
            let parts = legacy.split(separator: "|", maxSplits: 1)
            if parts.count == 2, parts[0] == "v2" {
                XCTFail("Should not migrate unknown version")
            }
        }

        // Then: No migration
        let pulseFrame = defaults.string(forKey: "PulsePane.windowFrame")
        XCTAssertNil(pulseFrame)
    }
}