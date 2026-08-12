#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI

/// A development-only view that exposes the current machine state and the latest
/// reducer lifecycle event. It intentionally renders values with `String(describing:)`
/// so it can be used with any Sendable State and Action.
@MainActor
public struct ObservationDebugOverlay<State: Equatable & Sendable, Action: Sendable>: View {
    private let machine: ObservationDrivenStateMachine<State, Action>
    private let title: String

    public init(
        machine: ObservationDrivenStateMachine<State, Action>,
        title: String = "StateObservationKit Debug"
    ) {
        self.machine = machine
        self.title = title
    }

    public var body: some View {
        let snapshot = machine.debugSnapshot

        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
            Text("State: \(String(describing: snapshot.state))")
            Text("Last action: \(snapshot.lastAction.map(String.init(describing:)) ?? "—")")
            Text("Phase: \(snapshot.lastPhase?.rawValue ?? "—")")
            Text("Pending: \(snapshot.pendingActionCount)")
        }
        .font(.caption2)
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
#endif
