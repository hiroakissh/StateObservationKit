import Foundation
#if canImport(Observation)
import Observation
#endif

#if canImport(Observation)
@Observable
#endif
@MainActor
public final class ObservationDrivenStateMachineMock<State: Equatable & Sendable, Action: Sendable>: ObservationStateMachineType {
    public private(set) var state: State
    public private(set) var receivedActions: [Action] = []
    private let availability: (State, Action) -> Bool
    private let reducer: ((inout State, Action) -> Void)?

    public init(
        initial: State,
        canSend: @escaping (State, Action) -> Bool = { _, _ in true },
        reducer: ((inout State, Action) -> Void)? = nil
    ) {
        self.state = initial
        self.availability = canSend
        self.reducer = reducer
    }

    public func canSend(_ action: Action) -> Bool {
        availability(state, action)
    }

    public func dispatch(_ action: Action) {
        receivedActions.append(action)
        guard canSend(action) else {
            return
        }
        var nextState = state
        reducer?(&nextState, action)
        state = nextState
    }
}
