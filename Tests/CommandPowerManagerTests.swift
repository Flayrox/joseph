import XCTest
@testable import joseph

final class CommandPowerManagerTests: XCTestCase {
    func testParsesBothPowerProfilesAndDisableSleep() throws {
        let output = """
        Battery Power:
         sleep                1
         displaysleep         2
        AC Power:
         sleep                0
         displaysleep         10
         disablesleep         1
        """

        let settings = try PMSetPowerSettings.parse(from: output)
        XCTAssertEqual(settings.batterySleep, "1")
        XCTAssertEqual(settings.batteryDisplaySleep, "2")
        XCTAssertEqual(settings.chargerSleep, "0")
        XCTAssertEqual(settings.chargerDisplaySleep, "10")
        XCTAssertEqual(settings.disableSleep, "1")
    }

    func testRejectsMalformedSnapshot() {
        XCTAssertThrowsError(try PMSetPowerSettings.parse(from: "Battery Power:\n sleep nope"))
    }
}
