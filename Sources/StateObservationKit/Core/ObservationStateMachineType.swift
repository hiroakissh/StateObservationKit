@MainActor
public protocol ObservationStateMachineType: AnyObject {
    associatedtype State: Equatable & Sendable
    associatedtype Action: Sendable

    var state: State { get }
    func dispatch(_ action: Action)
}
