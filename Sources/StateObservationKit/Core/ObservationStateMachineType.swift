@MainActor
public protocol ObservationStateMachineType: AnyObject {
    associatedtype State: Equatable & Sendable
    associatedtype Action: Sendable

    var state: State { get }
    func canSend(_ action: Action) -> Bool
    func dispatch(_ action: Action)
}

public extension ObservationStateMachineType {
    func send(_ action: Action) {
        dispatch(action)
    }

    func project<Projection>(_ transform: (State) -> Projection) -> Projection {
        transform(state)
    }
}
