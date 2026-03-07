import Foundation

public actor TransitionDrivenStateMachine<T: TransitionType>: Sendable {
    public private(set) var state: T.State
    private let hook: (@Sendable (T.State) -> Void)?

    public init(initial: T.State, hook: (@Sendable (T.State) -> Void)? = nil) {
        self.state = initial
        self.hook = hook
        hook?(initial)
    }

    public func dispatch(_ action: T.Action) async throws {
        let transition = try matchTransition(for: action)
        let followUpAction: T.Action?

        if let effect = transition.effect {
            do {
                followUpAction = try await effect()
            } catch {
                throw TransitionDispatchError<T>.effectFailed(
                    transition: transition,
                    message: String(describing: error)
                )
            }
        } else {
            followUpAction = nil
        }

        state = transition.to
        hook?(state)

        if let followUpAction {
            try await dispatch(followUpAction)
        }
    }

    private func matchTransition(for action: T.Action) throws -> T {
        guard let transition = T.allCases.first(where: { $0.from == state && $0.action == action }) else {
            throw TransitionDispatchError<T>.invalidTransition(state: state, action: action)
        }

        return transition
    }
}
