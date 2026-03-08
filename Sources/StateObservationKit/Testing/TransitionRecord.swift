public struct TransitionRecord<T: TransitionType>: Sendable, Equatable {
    public let action: T.Action
    public let transition: T
    public let fromState: T.State
    public let toState: T.State
    public let followUpAction: T.Action?

    public init(
        action: T.Action,
        transition: T,
        fromState: T.State,
        toState: T.State,
        followUpAction: T.Action? = nil
    ) {
        self.action = action
        self.transition = transition
        self.fromState = fromState
        self.toState = toState
        self.followUpAction = followUpAction
    }
}
