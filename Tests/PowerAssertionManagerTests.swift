import XCTest
@testable import joseph

@MainActor
final class PowerAssertionManagerTests: XCTestCase {
    func testEnableCreatesTwoAssertionsAndDisableReleasesThem() {
        let provider = SpyPowerProvider()
        let manager = PowerAssertionManager(provider: provider)

        XCTAssertTrue(manager.enableKeepAwake(reason: "test"))
        XCTAssertTrue(manager.isActive)
        XCTAssertEqual(provider.created.count, 2)

        manager.disableKeepAwake()
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(provider.released.count, 2)
    }

    func testEnableIsIdempotent() {
        let provider = SpyPowerProvider()
        let manager = PowerAssertionManager(provider: provider)

        XCTAssertTrue(manager.enableKeepAwake())
        XCTAssertTrue(manager.enableKeepAwake())
        XCTAssertEqual(provider.created.count, 2)
    }

    func testPrimaryFailureDoesNotActivateManager() {
        let provider = SpyPowerProvider(primaryResult: kIOReturnError)
        let manager = PowerAssertionManager(provider: provider)

        XCTAssertFalse(manager.enableKeepAwake())
        XCTAssertFalse(manager.isActive)
        XCTAssertTrue(provider.created.count == 1)
    }
}

private final class SpyPowerProvider: PowerAssertionProviding {
    var created: [(CFString, CFString)] = []
    var released: [IOPMAssertionID] = []
    let primaryResult: IOReturn

    init(primaryResult: IOReturn = kIOReturnSuccess) {
        self.primaryResult = primaryResult
    }

    func create(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID) {
        created.append((type, reason))
        if created.count == 1, primaryResult != kIOReturnSuccess { return (primaryResult, IOPMAssertionID(kIOPMNullAssertionID)) }
        return (kIOReturnSuccess, IOPMAssertionID(created.count))
    }

    func release(_ assertionID: IOPMAssertionID) -> IOReturn {
        released.append(assertionID)
        return kIOReturnSuccess
    }
}
