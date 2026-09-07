import XCTest
@testable import PulsePane

final class NetworkPolicyTests: XCTestCase {

    func testLoopbackExcluded() {
        let excluded = ["lo", "lo0", "lo1"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testAWDLExcluded() {
        let excluded = ["awdl0", "awdl1", "awdl2"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testLLWExcluded() {
        let excluded = ["llw0", "llw1"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testUTUNExcluded() {
        let excluded = ["utun0", "utun1", "utun5", "utun10"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testIPSecExcluded() {
        let excluded = ["ipsec0", "ipsec1"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testGIFExcluded() {
        let excluded = ["gif0", "gif1"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testSTFExcluded() {
        let excluded = ["stf0", "stf1"]
        for prefix in excluded {
            let result = NetworkReader.isTrackedInterface(prefix)
            XCTAssertFalse(result, "\(prefix) should be excluded")
        }
    }

    func testValidInterfacesIncluded() {
        let valid = ["en0", "en1", "en2", "en3", "bridge0", "bridge100"]
        for name in valid {
            let result = NetworkReader.isTrackedInterface(name)
            XCTAssertTrue(result, "\(name) should be included")
        }
    }

    func testEmptyStringExcluded() {
        XCTAssertFalse(NetworkReader.isTrackedInterface(""))
    }

    // Note: Integration tests for actual interface enumeration would require
    // actual network interfaces and are not suitable for unit tests.
    // These tests verify the policy logic only.
}