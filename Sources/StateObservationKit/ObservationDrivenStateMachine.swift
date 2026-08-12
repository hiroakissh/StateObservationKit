import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
@MainActor
/// Publishes state for Observation-driven UI code while serializing reducer execution internally.
/// `dispatch(_:)` is fire-and-forget, while `send(_:)` awaits the committed state on the same ordered queue.
public final class ObservationDrivenStateMachine<State: Equatable & Sendable, Action: Sendable>: ObservationStateMachineType {
    public private(set) var state: State
    public private(set) var pendingActionCount = 0
    public private(set) var lastAction: Action?
    public private(set) var lastTracePhase: ObservationTracePhase?
#if canImport(Observation)
    @ObservationIgnored
#endif
    private let reducerExecutor: ReducerExecutor<State, Action>
    private let availability: @Sendable (State, Action) -> Bool
    private var pendingCommit: Task<Void, Never>?
    private let traceRecorder: ObservationTraceRecorder<State, Action>?
    private let logger: ObservationTraceLogger?
    private let traceHandler: (@MainActor @Sendable (ObservationTraceEvent<State, Action>) -> Void)?
    private var traceSequence: UInt64 = 0

    public init(
        initial: State,
        canSend: @escaping @Sendable (State, Action) -> Bool = { _, _ in true },
        reducer: @escaping @Sendable (inout State, Action) async -> Void,
        traceRecorder: ObservationTraceRecorder<State, Action>? = nil,
        logger: ObservationTraceLogger? = nil,
        traceHandler: (@MainActor @Sendable (ObservationTraceEvent<State, Action>) -> Void)? = nil
    ) {
        self.state = initial
        self.availability = canSend
        self.reducerExecutor = ReducerExecutor(
            initial: initial,
            canSend: canSend,
            reducer: reducer
        )
        self.traceRecorder = traceRecorder
        self.logger = logger
        self.traceHandler = traceHandler
        traceRecorder?.recordInitialState(initial)
    }

    public func canSend(_ action: Action) -> Bool {
        pendingActionCount == 0 && availability(state, action)
    }

    public var debugSnapshot: ObservationDebugSnapshot<State, Action> {
        ObservationDebugSnapshot(
            state: state,
            pendingActionCount: pendingActionCount,
            lastAction: lastAction,
            lastPhase: lastTracePhase
        )
    }

    /// Schedules reducer execution and returns immediately.
    /// The action is enqueued on the same ordered reducer queue used by `send(_:)`.
    public func dispatch(_ action: Action) {
        _ = enqueue(action)
    }

    /// Enqueues reducer execution and waits until the resulting state has been published on the main actor.
    @discardableResult
    public func send(_ action: Action) async -> State {
        await enqueue(action).value
    }

    private func enqueue(_ action: Action) -> Task<State, Never> {
        let previousCommit = pendingCommit
        let reducerExecutor = self.reducerExecutor
        pendingActionCount += 1
        emit(
            phase: .enqueued,
            action: action,
            state: state
        )

        let task = Task<State, Never> { [weak self] in
            _ = await previousCommit?.value

            await MainActor.run {
                self?.emit(
                    phase: .started,
                    action: action,
                    state: self?.state
                )
            }

            let result = await reducerExecutor.run(action: action)

            await MainActor.run {
                if let self {
                    if result.accepted {
                        self.state = result.state
                    }
                    self.pendingActionCount -= 1
                    self.emit(
                        phase: result.accepted ? .committed : .rejected,
                        action: action,
                        state: result.previousState,
                        nextState: result.accepted ? result.state : nil
                    )
                }
            }

            return result.state
        }

        pendingCommit = Task {
            _ = await task.value
        }

        return task
    }

    private func emit(
        phase: ObservationTracePhase,
        action: Action,
        state: State?,
        nextState: State? = nil
    ) {
        guard let state else { return }

        traceSequence &+= 1
        lastAction = action
        lastTracePhase = phase
        let event = ObservationTraceEvent(
            sequence: traceSequence,
            phase: phase,
            action: action,
            state: state,
            nextState: nextState,
            pendingActionCount: pendingActionCount
        )
        traceRecorder?.record(event)
        logger?.log(event)
        traceHandler?(event)
    }
}

private struct ReducerRunResult<State: Sendable>: Sendable {
    let previousState: State
    let state: State
    let accepted: Bool
}

private actor ReducerExecutor<State: Sendable, Action: Sendable> {
    private var state: State
    private let canSend: @Sendable (State, Action) -> Bool
    private let reducer: @Sendable (inout State, Action) async -> Void

    init(
        initial: State,
        canSend: @escaping @Sendable (State, Action) -> Bool,
        reducer: @escaping @Sendable (inout State, Action) async -> Void
    ) {
        self.state = initial
        self.canSend = canSend
        self.reducer = reducer
    }

    func run(action: Action) async -> ReducerRunResult<State> {
        let previousState = state
        guard canSend(state, action) else {
            return ReducerRunResult(
                previousState: previousState,
                state: state,
                accepted: false
            )
        }

        var nextState = state
        await reducer(&nextState, action)
        state = nextState
        return ReducerRunResult(
            previousState: previousState,
            state: state,
            accepted: true
        )
    }
}
