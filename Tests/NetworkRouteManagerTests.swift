import XCTest
@testable import joseph

final class NetworkRouteManagerTests: XCTestCase {
    func testParsesServiceNamesAndDevices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        (1) Wi-Fi
        (Hardware Port: Wi-Fi, Device: en0)
        (2) iPhone USB
        (Hardware Port: iPhone USB, Device: en7)
        (3) Thunderbolt Bridge
        (Hardware Port: Thunderbolt Bridge, Device: bridge0)
        """

        XCTAssertEqual(
            NetworkServiceOrderParser.parse(output),
            [
                NetworkService(name: "Wi-Fi", device: "en0"),
                NetworkService(name: "iPhone USB", device: "en7"),
                NetworkService(name: "Thunderbolt Bridge", device: "bridge0")
            ]
        )
    }
}
