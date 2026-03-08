@MainActor
/// Abstraction for Observation-facing state machines used by UI orchestration, previews, and tests.
/// Depend on this protocol at injection boundaries; use concrete machines only when validating
/// runtime-specific behavior such as reducer queue ordering.
public protocol ObservationStateMachineType: AnyObject {
    associatedtype State: Equatable & Sendable
    associatedtype Action: Sendable

    var state: State { get }
    func canSend(_ action: Action) -> Bool
    func dispatch(_ action: Action)
    @discardableResult
    func send(_ action: Action) async -> State
}

public extension ObservationStateMachineType {
    func project<Projection>(_ transform: (State) -> Projection) -> Projection {
        transform(state)
    }
}
