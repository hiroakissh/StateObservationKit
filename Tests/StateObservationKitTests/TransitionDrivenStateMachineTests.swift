import Foundation
import XCTest
import StateObservationKit

final class TransitionDrivenStateMachineTests: XCTestCase {
    func testPlayerTransitionsUpdateStateAndHook() async throws {
        let recorder = StateSequenceRecorder<PlayerState>()
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
        let recorder = StateSequenceRecorder<PlayerState>()
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
        let recorder = StateSequenceRecorder<FailingState>()
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
        let recorder = StateSequenceRecorder<CancellationState>()
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
        let recorder = StateSequenceRecorder<FollowUpSuccessState>()
        let machine = TransitionDrivenStateMachine<FollowUpSuccessTransition>(
            initial: .idle,
            hook: { recorder.record($0) }
        )

        try await machine.dispatch(.start)

        let finalState = await machine.state
        XCTAssertEqual(finalState, .ready)
        XCTAssertEqual(recorder.snapshot, [.idle, .loading, .ready])
    }

    func testTransitionRecorderCapturesCommittedTransitionsAndFollowUpActions() async throws {
        let recorder = TransitionRecorder<FollowUpSuccessTransition>()
        let machine = TransitionDrivenStateMachine<FollowUpSuccessTransition>(
            initial: .idle,
            transitionRecorder: recorder
        )

        try await machine.dispatch(.start)

        XCTAssertEqual(recorder.actions, [.start, .finish])
        XCTAssertEqual(recorder.transitions, [.idle_start, .loading_finish])
        XCTAssertEqual(recorder.followUpActions, [.finish])
        XCTAssertEqual(recorder.stateSequence, [.idle, .loading, .ready])
        XCTAssertEqual(
            recorder.snapshot,
            [
                TransitionRecord(
                    action: .start,
                    transition: .idle_start,
                    fromState: .idle,
                    toState: .loading,
                    followUpAction: .finish
                ),
                TransitionRecord(
                    action: .finish,
                    transition: .loading_finish,
                    fromState: .loading,
                    toState: .ready
                )
            ]
        )
    }

    func testFollowUpFailureDoesNotRollbackCommittedTransition() async throws {
        let recorder = StateSequenceRecorder<FollowUpFailureState>()
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

    func testTransitionRecorderSkipsFailedTransitions() async throws {
        let recorder = TransitionRecorder<FollowUpFailureTransition>()
        let machine = TransitionDrivenStateMachine<FollowUpFailureTransition>(
            initial: .idle,
            transitionRecorder: recorder
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

        XCTAssertEqual(recorder.snapshot, [
            TransitionRecord(
                action: .start,
                transition: .idle_start,
                fromState: .idle,
                toState: .loading,
                followUpAction: .finish
            )
        ])
        XCTAssertEqual(recorder.stateSequence, [.idle, .loading])
    }

    func testPlayerExampleCanSwapUseCaseDependency() async throws {
        let useCase = RecordingPlayerUseCase()

        try await withPlayerExampleEnvironment(.init(playerUseCase: useCase)) {
            let machine = TransitionDrivenStateMachine<PlayerTransition>(initial: .idle)
            try await machine.dispatch(.play)
            try await machine.dispatch(.pause)
        }

        let calls = await useCase.calls
        XCTAssertEqual(calls, [.play, .pause])
    }

    func testWithPlayerExampleEnvironmentRestoresPreviousEnvironmentOnError() async {
        let overriddenUseCase = RecordingPlayerUseCase()

        do {
            try await withPlayerExampleEnvironment(.init(playerUseCase: overriddenUseCase)) {
                throw TestFailure.sample
            }
            XCTFail("Expected sample failure")
        } catch TestFailure.sample {
            // Expected path.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let machine = TransitionDrivenStateMachine<PlayerTransition>(initial: .idle)
        do {
            try await machine.dispatch(.play)
        } catch {
            XCTFail("Expected live environment to be restored, but got error: \(error)")
        }

        let calls = await overriddenUseCase.calls
        XCTAssertEqual(calls, [])
    }

    func testWithPlayerExampleEnvironmentIsolatesConcurrentScopes() async throws {
        let firstUseCase = RecordingPlayerUseCase()
        let secondUseCase = RecordingPlayerUseCase()
        let gate = ScopedPlayerEnvironmentGate()

        let firstTask = Task {
            await withPlayerExampleEnvironment(.init(playerUseCase: firstUseCase)) {
                await gate.markFirstScopeEntered()
                await gate.waitForSecondScopeEntered()
            }
            await gate.markFirstScopeExited()
        }

        await gate.waitForFirstScopeEntered()

        let secondTask = Task {
            try await withPlayerExampleEnvironment(.init(playerUseCase: secondUseCase)) {
                await gate.markSecondScopeEntered()
                await gate.waitForFirstScopeExited()

                let machine = TransitionDrivenStateMachine<PlayerTransition>(initial: .idle)
                try await machine.dispatch(.play)
            }
        }

        await firstTask.value
        try await secondTask.value

        let firstCalls = await firstUseCase.calls
        let secondCalls = await secondUseCase.calls
        XCTAssertEqual(firstCalls, [])
        XCTAssertEqual(secondCalls, [.play])
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

private actor RecordingPlayerUseCase: PlayerUseCaseProtocol {
    private(set) var calls: [PlayerCall] = []

    func play() async throws {
        calls.append(.play)
    }

    func pause() async throws {
        calls.append(.pause)
    }

    func resume() async throws {
        calls.append(.resume)
    }

    func stop() async throws {
        calls.append(.stop)
    }
}

private actor ScopedPlayerEnvironmentGate {
    private var firstScopeEntered = false
    private var secondScopeEntered = false
    private var firstScopeExited = false

    private var firstScopeEnteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var secondScopeEnteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstScopeExitedWaiters: [CheckedContinuation<Void, Never>] = []

    func markFirstScopeEntered() {
        firstScopeEntered = true
        resumeAll(&firstScopeEnteredWaiters)
    }

    func waitForFirstScopeEntered() async {
        guard !firstScopeEntered else { return }
        await withCheckedContinuation { continuation in
            firstScopeEnteredWaiters.append(continuation)
        }
    }

    func markSecondScopeEntered() {
        secondScopeEntered = true
        resumeAll(&secondScopeEnteredWaiters)
    }

    func waitForSecondScopeEntered() async {
        guard !secondScopeEntered else { return }
        await withCheckedContinuation { continuation in
            secondScopeEnteredWaiters.append(continuation)
        }
    }

    func markFirstScopeExited() {
        firstScopeExited = true
        resumeAll(&firstScopeExitedWaiters)
    }

    func waitForFirstScopeExited() async {
        guard !firstScopeExited else { return }
        await withCheckedContinuation { continuation in
            firstScopeExitedWaiters.append(continuation)
        }
    }

    private func resumeAll(_ continuations: inout [CheckedContinuation<Void, Never>]) {
        let waiters = continuations
        continuations.removeAll(keepingCapacity: true)
        for continuation in waiters {
            continuation.resume()
        }
    }
}

private enum PlayerCall: Equatable {
    case play
    case pause
    case resume
    case stop
}
