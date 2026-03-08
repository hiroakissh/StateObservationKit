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
#if canImport(Observation)
    @ObservationIgnored
#endif
    private let reducerExecutor: ReducerExecutor<State, Action>
    private let availability: @Sendable (State, Action) -> Bool
    private var pendingCommit: Task<Void, Never>?

    public init(
        initial: State,
        canSend: @escaping @Sendable (State, Action) -> Bool = { _, _ in true },
        reducer: @escaping @Sendable (inout State, Action) async -> Void
    ) {
        self.state = initial
        self.availability = canSend
        self.reducerExecutor = ReducerExecutor(
            initial: initial,
            canSend: canSend,
            reducer: reducer
        )
    }

    public func canSend(_ action: Action) -> Bool {
        availability(state, action)
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

        let task = Task<State, Never> { [weak self] in
            _ = await previousCommit?.value

            let newState = await reducerExecutor.run(action: action)

            await MainActor.run {
                self?.state = newState
            }

            return newState
        }

        pendingCommit = Task {
            _ = await task.value
        }

        return task
    }
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

    func run(action: Action) async -> State {
        guard canSend(state, action) else {
            return state
        }

        var nextState = state
        await reducer(&nextState, action)
        state = nextState
        return state
    }
}
