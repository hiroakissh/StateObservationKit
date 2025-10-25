import Foundation

public actor TransitionDrivenStateMachine<T: TransitionType>: Sendable {
    private(set) var state: T.State
    private let hook: ((T.State) -> Void)?

    public init(initial: T.State, hook: ((T.State) -> Void)? = nil) {
        self.state = initial
        self.hook = hook
        hook?(initial)
    }

    public func dispatch(_ action: T.Action) async {
        guard let transition = matchTransition(for: action) else {
            print("⚠️ Invalid transition: \(state) × \(action)")
            return
        }

        if let effect = transition.effect {
            do { try await effect() }
            catch { print("⚠️ Effect failed:", error) }
        }

        state = transition.to
        hook?(state)
    }

    private func matchTransition(for action: T.Action) -> T? {
        T.allCases.first(where: { $0.from == state && $0.action == action })
    }
}
