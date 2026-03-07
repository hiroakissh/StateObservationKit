import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif
@testable import StateObservationKit

private struct AvailabilityState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case idle
        case running
    }

    var phase: Phase
    var acceptedStarts: Int
}

private enum AvailabilityAction: Equatable, Sendable {
    case start
}

private struct DraftState: Equatable, Sendable {
    var title: String
    var isSaving: Bool
}

private enum DraftAction: Equatable, Sendable {
    case titleChanged(String)
    case saveTapped
}

final class ObservationDrivenStateMachineTests: XCTestCase {
    @MainActor
    func testReducerFlow() async throws {
        let machine = ObservationDrivenStateMachine(initial: "idle") { state, action in
            if action == "start" { state = "running" }
        }

        XCTAssertEqual(machine.state, "idle")
        machine.send("start")

        try await assertEventually {
            machine.state == "running"
        }
    }

    @MainActor
    func testCanSendReflectsStateAndGuardsQueuedActions() async throws {
        let machine: ObservationDrivenStateMachine<AvailabilityState, AvailabilityAction> = ObservationDrivenStateMachine(
            initial: AvailabilityState(phase: .idle, acceptedStarts: 0),
            canSend: { state, action in
                switch (state.phase, action) {
                case (.idle, .start):
                    return true
                default:
                    return false
                }
            }
        ) { state, action in
            switch action {
            case .start:
                state.phase = .running
                state.acceptedStarts += 1
            }
        }

        XCTAssertTrue(machine.canSend(.start))

        machine.send(.start)
        machine.send(.start)

        try await assertEventually {
            machine.state == AvailabilityState(phase: .running, acceptedStarts: 1)
        }
        XCTAssertFalse(machine.canSend(.start))
    }

    @MainActor
    func testMockRecordsActionsAndRespectsAvailability() {
        let mock: ObservationDrivenStateMachineMock<String, String> = ObservationDrivenStateMachineMock(
            initial: "idle",
            canSend: { state, action in
                state == "idle" && action == "start"
            }
        ) { state, action in
            if action == "start" { state = "running" }
        }

        XCTAssertEqual(mock.state, "idle")
        XCTAssertTrue(mock.receivedActions.isEmpty)
        XCTAssertTrue(mock.canSend("start"))

        mock.dispatch("start")
        mock.dispatch("start")

        XCTAssertEqual(mock.state, "running")
        XCTAssertFalse(mock.canSend("start"))
        XCTAssertEqual(mock.receivedActions, ["start", "start"])
    }

#if canImport(SwiftUI)
    @MainActor
    func testBindingDispatchesActionAndProjectionDerivesViewState() {
        let mock: ObservationDrivenStateMachineMock<DraftState, DraftAction> = ObservationDrivenStateMachineMock(
            initial: DraftState(title: "", isSaving: false),
            canSend: { state, action in
                switch action {
                case .titleChanged:
                    return true
                case .saveTapped:
                    return !state.title.isEmpty
                }
            }
        ) { state, action in
            switch action {
            case .titleChanged(let title):
                state.title = title
            case .saveTapped:
                state.isSaving = true
            }
        }

        let titleBinding = mock.binding(\DraftState.title, send: DraftAction.titleChanged)
        XCTAssertEqual(titleBinding.wrappedValue, "")

        titleBinding.wrappedValue = "Ship Q3"
        XCTAssertEqual(mock.state.title, "Ship Q3")

        let viewState = mock.project { state in
            DraftViewState(title: state.title, canSave: mock.canSend(.saveTapped))
        }
        XCTAssertEqual(viewState, DraftViewState(title: "Ship Q3", canSave: true))

        mock.send(.saveTapped)

        XCTAssertTrue(mock.state.isSaving)
        XCTAssertEqual(
            mock.receivedActions,
            [DraftAction.titleChanged("Ship Q3"), .saveTapped]
        )
    }
#endif

    @MainActor
    private func assertEventually(
        timeout: Duration = .seconds(1),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let start = clock.now

        while clock.now - start < timeout {
            if condition() {
                return
            }

            try await Task.sleep(for: .milliseconds(10))
        }

        XCTFail("Condition was not satisfied in time", file: file, line: line)
    }
}

#if canImport(SwiftUI)
private struct DraftViewState: Equatable {
    let title: String
    let canSave: Bool
}
#endif
