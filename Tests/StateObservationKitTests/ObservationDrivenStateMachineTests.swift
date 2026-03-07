import XCTest
@testable import StateObservationKit

final class ObservationDrivenStateMachineTests: XCTestCase {
    @MainActor
    func testReducerFlow() async throws {
        let machine = ObservationDrivenStateMachine(initial: "idle") { state, action in
            if action == "start" { state = "running" }
        }

        XCTAssertEqual(machine.state, "idle")
        machine.dispatch("start")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(machine.state, "running")
    }

    @MainActor
    func testMockRecordsActionsAndState() {
        let mock = ObservationDrivenStateMachineMock(initial: "idle") { state, action in
            if action == "start" { state = "running" }
        }

        XCTAssertEqual(mock.state, "idle")
        XCTAssertTrue(mock.receivedActions.isEmpty)

        mock.dispatch("start")

        XCTAssertEqual(mock.state, "running")
        XCTAssertEqual(mock.receivedActions, ["start"])
    }
}
