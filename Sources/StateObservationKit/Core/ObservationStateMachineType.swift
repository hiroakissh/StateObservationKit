public protocol ObservationStateMachineType: AnyObject {
    associatedtype State: Equatable
    associatedtype Action

    var state: State { get }
    func dispatch(_ action: Action)
}
