import Foundation
#if canImport(Observation)
import Observation

@Observable
public final class ObservationDrivenStateMachine<State: Equatable, Action> {
    public private(set) var state: State
    private let reducer: (inout State, Action) async -> Void

    public init(initial: State, reducer: @escaping (inout State, Action) async -> Void) {
        self.state = initial
        self.reducer = reducer
    }

    public func dispatch(_ action: Action) {
        Task {
            var newState = state
            await reducer(&newState, action)
            let updatedState = newState
            await MainActor.run { self.state = updatedState }
        }
    }
}
#else
public final class ObservationDrivenStateMachine<State: Equatable, Action> {
    public private(set) var state: State
    private let reducer: (inout State, Action) async -> Void

    public init(initial: State, reducer: @escaping (inout State, Action) async -> Void) {
        self.state = initial
        self.reducer = reducer
    }

    public func dispatch(_ action: Action) {
        Task {
            var newState = state
            await reducer(&newState, action)
            let updatedState = newState
            await MainActor.run { self.state = updatedState }
        }
    }
}
#endif
