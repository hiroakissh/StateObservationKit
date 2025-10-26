import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
public final class ObservationDrivenStateMachine<State: Equatable, Action> {
    public private(set) var state: State
#if canImport(Observation)
    @ObservationIgnored
#endif
    private let reducerExecutor: ReducerExecutor<State, Action>

    public init(initial: State, reducer: @escaping (inout State, Action) async -> Void) {
        self.state = initial
        self.reducerExecutor = ReducerExecutor(initial: initial, reducer: reducer)
    }

    public func dispatch(_ action: Action) {
        Task {
            let newState = await reducerExecutor.run(action: action)
            await MainActor.run { self.state = newState }
        }
    }
}

private actor ReducerExecutor<State, Action> {
    private var state: State
    private let reducer: (inout State, Action) async -> Void

    init(initial: State, reducer: @escaping (inout State, Action) async -> Void) {
        self.state = initial
        self.reducer = reducer
    }

    func run(action: Action) async -> State {
        var nextState = state
        await reducer(&nextState, action)
        state = nextState
        return state
    }
}
