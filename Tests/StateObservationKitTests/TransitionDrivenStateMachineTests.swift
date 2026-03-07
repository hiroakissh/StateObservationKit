import Foundation
import XCTest
import StateObservationKit

final class TransitionDrivenStateMachineTests: XCTestCase {
    func testPlayerTransitionsUpdateStateAndHook() async throws {
        let recorder = StateRecorder<PlayerState>()
        let machine = TransitionDrivenStateMachine<PlayerTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        try await machine.dispatch(.play)
        try await machine.dispatch(.pause)
        try await machine.dispatch(.resume)
        try await machine.dispatch(.stop)

        let finalState = await machine.state
        XCTAssertEqual(finalState, .stopped)
        XCTAssertEqual(
            recorder.snapshot,
            [.idle, .playing, .paused, .playing, .stopped]
        )
    }

    func testInvalidTransitionThrowsAndPreservesState() async throws {
        let recorder = StateRecorder<PlayerState>()
        let machine = TransitionDrivenStateMachine<PlayerTransition>(
            initial: .stopped,
            hook: { recorder.record($0) }
        )

        do {
            try await machine.dispatch(.pause)
            XCTFail("Expected invalid transition error")
        } catch let error as TransitionDispatchError<PlayerTransition> {
            XCTAssertEqual(error, .invalidTransition(state: .stopped, action: .pause))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let finalState = await machine.state
        XCTAssertEqual(finalState, .stopped)
        XCTAssertEqual(recorder.snapshot, [.stopped])
    }

    func testEffectFailureThrowsAndPreservesState() async throws {
        let recorder = StateRecorder<FailingState>()
        let machine = TransitionDrivenStateMachine<FailingTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        do {
            try await machine.dispatch(.start)
            XCTFail("Expected effect failure")
        } catch let error as TransitionDispatchError<FailingTransition> {
            switch error {
            case let .effectFailed(transition, message):
                XCTAssertEqual(transition, .idle_start)
                XCTAssertFalse(message.isEmpty)
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let finalState = await machine.state
        XCTAssertEqual(finalState, .idle)
        XCTAssertEqual(recorder.snapshot, [.idle])
    }

    func testCancellationErrorPropagatesWithoutWrapping() async throws {
        let recorder = StateRecorder<CancellationState>()
        let machine = TransitionDrivenStateMachine<CancellationTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        do {
            try await machine.dispatch(.start)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected path.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let finalState = await machine.state
        XCTAssertEqual(finalState, .idle)
        XCTAssertEqual(recorder.snapshot, [.idle])
    }

    func testFollowUpActionDispatchesNextTransition() async throws {
        let recorder = StateRecorder<FollowUpSuccessState>()
        let machine = TransitionDrivenStateMachine<FollowUpSuccessTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        try await machine.dispatch(.start)

        let finalState = await machine.state
        XCTAssertEqual(finalState, .ready)
        XCTAssertEqual(recorder.snapshot, [.idle, .loading, .ready])
    }

    func testFollowUpFailureDoesNotRollbackCommittedTransition() async throws {
        let recorder = StateRecorder<FollowUpFailureState>()
        let machine = TransitionDrivenStateMachine<FollowUpFailureTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        do {
            try await machine.dispatch(.start)
            XCTFail("Expected follow-up effect failure")
        } catch let error as TransitionDispatchError<FollowUpFailureTransition> {
            switch error {
            case let .effectFailed(transition, message):
                XCTAssertEqual(transition, .loading_finish)
                XCTAssertFalse(message.isEmpty)
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let finalState = await machine.state
        XCTAssertEqual(finalState, .loading)
        XCTAssertEqual(recorder.snapshot, [.idle, .loading])
    }
}

private final class StateRecorder<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [State] = []

    func record(_ state: State) {
        lock.lock()
        values.append(state)
        lock.unlock()
    }

    var snapshot: [State] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

private enum FailingState: StateType {
    case idle
    case loading
}

private enum FailingAction: ActionType {
    case start
}

private enum FailingTransition: TransitionType {
    typealias State = FailingState
    typealias Action = FailingAction

    case idle_start

    var from: State { .idle }
    var action: Action { .start }
    var to: State { .loading }

    var effect: (@Sendable () async throws -> Action?)? {
        {
            throw TestFailure.sample
        }
    }
}

private enum CancellationState: StateType {
    case idle
    case loading
}

private enum CancellationAction: ActionType {
    case start
}

private enum CancellationTransition: TransitionType {
    typealias State = CancellationState
    typealias Action = CancellationAction

    case idle_start

    var from: State { .idle }
    var action: Action { .start }
    var to: State { .loading }

    var effect: (@Sendable () async throws -> Action?)? {
        {
            throw CancellationError()
        }
    }
}

private enum FollowUpSuccessState: StateType {
    case idle
    case loading
    case ready
}

private enum FollowUpSuccessAction: ActionType {
    case start
    case finish
}

private enum FollowUpSuccessTransition: TransitionType {
    typealias State = FollowUpSuccessState
    typealias Action = FollowUpSuccessAction

    case idle_start
    case loading_finish

    var from: State {
        switch self {
        case .idle_start: .idle
        case .loading_finish: .loading
        }
    }

    var action: Action {
        switch self {
        case .idle_start: .start
        case .loading_finish: .finish
        }
    }

    var to: State {
        switch self {
        case .idle_start: .loading
        case .loading_finish: .ready
        }
    }

    var effect: (@Sendable () async throws -> Action?)? {
        switch self {
        case .idle_start:
            { .finish }
        case .loading_finish:
            nil
        }
    }
}

private enum FollowUpFailureState: StateType {
    case idle
    case loading
    case ready
}

private enum FollowUpFailureAction: ActionType {
    case start
    case finish
}

private enum FollowUpFailureTransition: TransitionType {
    typealias State = FollowUpFailureState
    typealias Action = FollowUpFailureAction

    case idle_start
    case loading_finish

    var from: State {
        switch self {
        case .idle_start: .idle
        case .loading_finish: .loading
        }
    }

    var action: Action {
        switch self {
        case .idle_start: .start
        case .loading_finish: .finish
        }
    }

    var to: State {
        switch self {
        case .idle_start: .loading
        case .loading_finish: .ready
        }
    }

    var effect: (@Sendable () async throws -> Action?)? {
        switch self {
        case .idle_start:
            { .finish }
        case .loading_finish:
            {
                throw TestFailure.sample
            }
        }
    }
}

private enum TestFailure: Error {
    case sample
}
