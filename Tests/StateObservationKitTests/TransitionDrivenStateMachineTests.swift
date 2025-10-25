import XCTest
@testable import StateObservationKit

final class TransitionDrivenStateMachineTests: XCTestCase {
    func testPlayerTransitions() async throws {
        let machine = TransitionDrivenStateMachine<PlayerTransition>(
            initial: .idle,
            hook: { print("🎯 State →", $0) }
        )

        await machine.dispatch(.play)
        await machine.dispatch(.pause)
        await machine.dispatch(.resume)
        await machine.dispatch(.stop)
    }
}
