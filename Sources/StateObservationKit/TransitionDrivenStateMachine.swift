import Foundation

/// Executes explicit `TransitionType` values for a `(state, action)` pair.
/// State is committed only through `dispatch(_:)`, after the matched transition's effect succeeds.
public actor TransitionDrivenStateMachine<T: TransitionType>: Sendable {
    public private(set) var state: T.State
    private let stateHook: (@Sendable (T.State) -> Void)?
    private let transitionRecorder: TransitionRecorder<T>?

    public init(
        initial: T.State,
        hook: (@Sendable (T.State) -> Void)? = nil,
        transitionRecorder: TransitionRecorder<T>? = nil
    ) {
        self.state = initial
        self.stateHook = hook
        self.transitionRecorder = transitionRecorder
        transitionRecorder?.recordInitialState(initial)
        hook?(initial)
    }

    /// Resolves the current `(state, action)` pair, runs the transition effect, and commits the next state.
    /// - Throws: `TransitionDispatchError.invalidTransition` when no transition matches the current state and action,
    ///   `TransitionDispatchError.effectFailed` when the effect throws a non-cancellation error, or `CancellationError`.
    public func dispatch(_ action: T.Action) async throws {
        // Process follow-up actions iteratively so chained transitions do not grow the call stack.
        var pendingAction: T.Action? = action

        while let currentAction = pendingAction {
            pendingAction = nil

            let previousState = state
            let transition = try matchTransition(for: currentAction)
            var followUpAction: T.Action?

            if let effect = transition.effect {
                do {
                    followUpAction = try await effect()
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
            transitionRecorder?.record(
                TransitionRecord(
                    action: currentAction,
                    transition: transition,
                    fromState: previousState,
                    toState: state,
                    followUpAction: followUpAction
                )
            )
            stateHook?(state)
            pendingAction = followUpAction
        }
    }

    private func matchTransition(for action: T.Action) throws -> T {
        guard let transition = T.allCases.first(where: { $0.from == state && $0.action == action }) else {
            throw TransitionDispatchError<T>.invalidTransition(state: state, action: action)
        }

        return transition
    }
}
