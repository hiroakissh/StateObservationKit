import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
@MainActor
public final class ObservationDrivenStateMachine<State: Equatable & Sendable, Action: Sendable>: ObservationStateMachineType {
    public private(set) var state: State
#if canImport(Observation)
    @ObservationIgnored
#endif
    private let reducerExecutor: ReducerExecutor<State, Action>
    private let availability: @Sendable (State, Action) -> Bool

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

    public func dispatch(_ action: Action) {
        let reducerExecutor = self.reducerExecutor
        Task {
            let newState = await reducerExecutor.run(action: action)
            self.state = newState
        }
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
