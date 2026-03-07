import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
@MainActor
/// API-shape-compatible test double for `ObservationDrivenStateMachine`.
/// It records input and runs its reducer synchronously, so use it for deterministic state assertions,
/// previews, and orchestration tests rather than reducer queue semantics.
public final class ObservationDrivenStateMachineMock<State: Equatable & Sendable, Action: Sendable>: ObservationStateMachineType {
    public private(set) var state: State
    public private(set) var receivedActions: [Action] = []
    private let reducer: ((inout State, Action) -> Void)?

    public init(initial: State, reducer: ((inout State, Action) -> Void)? = nil) {
        self.state = initial
        self.reducer = reducer
    }

    public func dispatch(_ action: Action) {
        receivedActions.append(action)
        var nextState = state
        reducer?(&nextState, action)
        state = nextState
    }

    @discardableResult
    public func send(_ action: Action) async -> State {
        dispatch(action)
        return state
    }
}
