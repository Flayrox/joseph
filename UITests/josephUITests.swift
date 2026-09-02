import Darwin
import XCTest

final class josephUITests: XCTestCase {

    @MainActor
    func testTogglesReflectAndChangeUnderlyingState() throws {
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        openMenuBarPanel(app)

        // Mode Voyage: a native IOKit assertion that `pmset -g assertions` exposes.
        let voyage = app.checkBoxes["toggle-voyage"]
        XCTAssertTrue(voyage.waitForExistence(timeout: 10), "Mode Voyage toggle should exist in the panel")
        XCTAssertTrue(waitForBadge(app, "Mode Voyage : Désactivé"), "Voyage badge should start disabled")

        voyage.click()
        XCTAssertTrue(waitForBadge(app, "Mode Voyage : Activé"), "Voyage badge should flip to enabled")
        XCTAssertTrue(
            waitForAssertion(named: "Mode Voyage", exists: true),
            "PreventSystemSleep assertion should be created when Mode Voyage is enabled"
        )

        voyage.click()
        XCTAssertTrue(waitForBadge(app, "Mode Voyage : Désactivé"), "Voyage badge should flip back to disabled")
        XCTAssertTrue(
            waitForAssertion(named: "Mode Voyage", exists: false),
            "Assertion should be released when Mode Voyage is disabled"
        )

        // caffeinate: a real `caffeinate -d` process must exist while enabled,
        // proven both by the process table and by its display-sleep assertion.
        let caffeinate = app.checkBoxes["toggle-caffeinate"]
        XCTAssertTrue(caffeinate.waitForExistence(timeout: 5), "caffeinate toggle should exist")

        caffeinate.click()
        XCTAssertTrue(waitForBadge(app, "caffeinate : Enabled"), "caffeinate badge should flip to enabled")
        XCTAssertTrue(waitForProcessNamed("caffeinate", exists: true), "caffeinate -d should be running")
        XCTAssertTrue(waitForAssertion(named: "caffeinate command-line tool", exists: true), "caffeinate -d should hold a display-sleep assertion")

        caffeinate.click()
        XCTAssertTrue(waitForBadge(app, "caffeinate : Disabled"), "caffeinate badge should flip back to disabled")
        XCTAssertTrue(waitForProcessNamed("caffeinate", exists: false), "caffeinate -d should be stopped")

        // Heartbeat: a `ping -i 15 1.1.1.1` process must exist while enabled.
        let heartbeat = app.checkBoxes["toggle-heartbeat"]
        XCTAssertTrue(heartbeat.waitForExistence(timeout: 5), "Heartbeat toggle should exist")

        heartbeat.click()
        XCTAssertTrue(waitForBadge(app, "heartbeat : Enabled"), "heartbeat badge should flip to enabled")
        XCTAssertTrue(waitForProcessNamed("ping", exists: true), "heartbeat ping should be running")

        heartbeat.click()
        XCTAssertTrue(waitForBadge(app, "heartbeat : Disabled"), "heartbeat badge should flip back to disabled")
        XCTAssertTrue(waitForProcessNamed("ping", exists: false), "heartbeat ping should be stopped")
    }

    // MARK: - Helpers

    @MainActor
    private func openMenuBarPanel(_ app: XCUIApplication) {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "joseph should expose a menu bar item after launch")
        XCTAssertEqual(statusItem.title, "joseph", "The status item should carry joseph's label")

        statusItem.click()

        // The panel content (menuBarExtraStyle .window) is exposed directly
        // under the app element: wait for one of our toggles to appear.
        let voyage = app.checkBoxes["toggle-voyage"]
        XCTAssertTrue(voyage.waitForExistence(timeout: 10), "Menu bar panel should open after clicking the status item")
    }

    private func waitForBadge(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let element = app.staticTexts[label]
        return waitUntil(timeout: timeout) { element.exists }
    }

    private func waitForAssertion(named fragment: String, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) {
            self.assertionOutput().contains(fragment) == exists
        }
    }

    private func waitForProcessNamed(_ name: String, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        waitUntil(timeout: timeout) {
            self.processRunning(name) == exists
        }
    }

    /// Enumerates the kernel process table with sysctl (ps is blocked inside the
    /// UI test runner) and reports whether a process with the exact name runs.
    private func processRunning(_ name: String) -> Bool {
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return false
        }
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.size)
        guard sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else {
            return false
        }
        let count = size / MemoryLayout<kinfo_proc>.size
        for i in 0..<count {
            let comm = withUnsafeBytes(of: procs[i].kp_proc.p_comm) { raw -> String in
                let chars = raw.bindMemory(to: CChar.self)
                return String(cString: chars.baseAddress!)
            }
            if comm == name {
                return true
            }
        }
        return false
    }

    private func assertionOutput() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return "" }
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return condition()
    }
}