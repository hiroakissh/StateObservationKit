#if canImport(SwiftUI)
import SwiftUI

@MainActor
public extension ObservationStateMachineType {
    func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        send action: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.dispatch(action($0)) }
        )
    }
}
#endif
