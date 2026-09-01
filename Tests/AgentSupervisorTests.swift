import XCTest
@testable import JOSEPH

@MainActor
final class AgentSupervisorTests: XCTestCase {
    func testRejectsRelativeOrMissingExecutable() {
        let supervisor = AgentSupervisor(outputLimit: 64)

        XCTAssertNil(supervisor.launch(executable: "missing-agent"))
        XCTAssertNotNil(supervisor.lastError)
    }

    func testCapturesOutputAndRecordsSuccessfulTermination() async throws {
        let supervisor = AgentSupervisor(outputLimit: 64)
        let id = try XCTUnwrap(supervisor.launch(
            executable: "/bin/sh",
            arguments: ["-c", "printf hello"]
        ))

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let process = supervisor.processes.first(where: { $0.id == id }), process.status != .running {
                XCTAssertEqual(process.status, .finished(0))
                XCTAssertTrue(process.output.contains("hello"))
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTFail("Process did not terminate before timeout")
    }

    func testOutputIsBounded() async throws {
        let supervisor = AgentSupervisor(outputLimit: 32)
        let id = try XCTUnwrap(supervisor.launch(
            executable: "/bin/sh",
            arguments: ["-c", "printf 1234567890123456789012345678901234567890"]
        ))

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let process = supervisor.processes.first(where: { $0.id == id }), process.status != .running {
                XCTAssertLessThanOrEqual(process.output.utf8.count, 64)
                XCTAssertTrue(process.output.contains("output truncated"))
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTFail("Process did not terminate before timeout")
    }
}
