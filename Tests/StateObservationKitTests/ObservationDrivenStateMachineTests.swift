import XCTest
@testable import StateObservationKit

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

#if canImport(SwiftUI) && canImport(Observation)
    @MainActor
    func testPlayerScreenModelCanUseMockThroughProtocolBoundary() {
        let machine = ObservationDrivenStateMachineMock<PlayerState, PlayerAction>(
            initial: .idle
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
        XCTAssertEqual(machine.receivedActions, [.play])
    }
#endif
}

private enum SampleAsyncResultError: Error {
    case example
}

#if canImport(SwiftUI) && canImport(Observation)
private actor NoOpPlayerUseCase: PlayerUseCaseProtocol {
    func play() async throws {}
    func pause() async throws {}
    func resume() async throws {}
    func stop() async throws {}
}
#endif
