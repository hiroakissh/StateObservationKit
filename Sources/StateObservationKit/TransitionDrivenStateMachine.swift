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
        // Process follow-up actions iteratively so chained transitions do not grow the call stack.
        var pendingAction: T.Action? = action

        while let currentAction = pendingAction {
            pendingAction = nil

            let transition = try matchTransition(for: currentAction)

            if let effect = transition.effect {
                do {
                    pendingAction = try await effect()
                } catch let error as CancellationError {
                    throw error
                } catch {
                    throw TransitionDispatchError<T>.effectFailed(
                        transition: transition,
                        message: String(describing: error)
                    )
                }
            }

            state = transition.to
            hook?(state)
        }
    }

    private func matchTransition(for action: T.Action) throws -> T {
        guard let transition = T.allCases.first(where: { $0.from == state && $0.action == action }) else {
            throw TransitionDispatchError<T>.invalidTransition(state: state, action: action)
        }

        return transition
    }
}
