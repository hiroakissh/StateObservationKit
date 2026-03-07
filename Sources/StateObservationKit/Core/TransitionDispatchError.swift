public enum TransitionDispatchError<T: TransitionType>: Error, Sendable, Equatable {
    case invalidTransition(state: T.State, action: T.Action)
    case effectFailed(transition: T, message: String)
}
