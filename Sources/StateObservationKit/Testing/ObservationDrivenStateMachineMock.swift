import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
public final class ObservationDrivenStateMachineMock<State: Equatable, Action>: ObservationStateMachineType {
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
}
