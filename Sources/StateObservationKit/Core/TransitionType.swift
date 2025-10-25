public protocol TransitionType: Equatable, Sendable, CaseIterable {
    associatedtype State: StateType
    associatedtype Action: ActionType

    var from: State { get }
    var action: Action { get }
    var to: State { get }
    var effect: (@Sendable () async throws -> Void)? { get }
}
