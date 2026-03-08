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
    func testAsyncResultCatchingReturnsSuccess() async {
        let result = await Result<Int, Error>.catching { 42 }

        switch result {
        case .success(let value):
            XCTAssertEqual(value, 42)
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testAsyncResultCatchingReturnsFailure() async {
        let result = await Result<Void, Error>.catching {
            throw SampleAsyncResultError.example
        }

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertTrue(error is SampleAsyncResultError)
        }
    }

    @MainActor
    func testSendWaitsForCommittedState() async {
        let machine = ObservationDrivenStateMachine(initial: "idle") { state, action in
            if action == "start" { state = "running" }
        }

        XCTAssertEqual(machine.state, "idle")
        let committedState = await machine.send("start")
        XCTAssertEqual(committedState, "running")
        XCTAssertEqual(machine.state, "running")
    }

    @MainActor
    func testCanSendReflectsStateAndGuardsQueuedActions() async {
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

        machine.dispatch(.start)
        let committedState = await machine.send(.start)

        XCTAssertEqual(
            committedState,
            AvailabilityState(phase: .running, acceptedStarts: 1)
        )
        XCTAssertEqual(machine.state, committedState)
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

    @MainActor
    func testDispatchAndSendShareTheSameOrderedQueue() async {
        let machine = ObservationDrivenStateMachine(initial: [String]()) { state, action in
            state.append(action)
        }

        machine.dispatch("first")
        let committedState = await machine.send("second")

        XCTAssertEqual(committedState, ["first", "second"])
        XCTAssertEqual(machine.state, ["first", "second"])
    }

#if canImport(SwiftUI)
    @MainActor
    func testBindingDispatchesActionAndProjectionDerivesViewState() async {
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

        let committedState = await mock.send(.saveTapped)

        XCTAssertEqual(committedState, DraftState(title: "Ship Q3", isSaving: true))
        XCTAssertEqual(mock.state, committedState)
        XCTAssertEqual(
            mock.receivedActions,
            [DraftAction.titleChanged("Ship Q3"), .saveTapped]
        )
    }
#endif

#if canImport(SwiftUI) && canImport(Observation)
    @MainActor
    func testPlayerScreenModelCanUseMockThroughProtocolBoundary() {
        let machine = ObservationDrivenStateMachineMock<PlayerState, PlayerAction>(
            initial: .idle,
            canSend: { state, action in
                switch (state, action) {
                case (.idle, .play),
                     (.playing, .pause),
                     (.playing, .stop),
                     (.paused, .resume),
                     (.paused, .stop),
                     (.stopped, .play):
                    return true
                default:
                    return false
                }
            }
        ) { state, action in
            switch (state, action) {
            case (.idle, .play):
                state = .playing
            case (.playing, .pause):
                state = .paused
            case (.paused, .resume):
                state = .playing
            case (.playing, .stop), (.paused, .stop):
                state = .stopped
            default:
                break
            }
        }

        let model = PlayerScreenModel(
            machine: machine,
            playerUseCase: NoOpPlayerUseCase()
        )

        model.send(.play)

        XCTAssertEqual(model.state, .playing)
        XCTAssertTrue(model.canSend(.pause))
        XCTAssertEqual(machine.receivedActions, [.play])
    }
#endif
}

private enum SampleAsyncResultError: Error {
    case example
}

#if canImport(SwiftUI)
private struct DraftViewState: Equatable {
    let title: String
    let canSave: Bool
}
#endif

#if canImport(SwiftUI) && canImport(Observation)
private actor NoOpPlayerUseCase: PlayerUseCaseProtocol {
    func play() async throws {}
    func pause() async throws {}
    func resume() async throws {}
    func stop() async throws {}
}
#endif
