# Clean Architecture Integration Guide

StateObservationKit belongs in the Application layer. The consuming application owns its UseCase, Domain, and Infrastructure layers.

```text
View
 ↓ Action
ScreenModel / Application StateMachine
 ↓
UseCase / Domain
 ↓
Repository / API Client / System Service
```

Define the boundary the application needs instead of making the machine know a concrete persistence or networking implementation.

```swift
protocol FormSubmissionUseCaseProtocol: Sendable {
    func submit(_ draft: FormSubmissionDraft) async throws
}

struct FormSubmissionEnvironment: Sendable {
    let useCase: any FormSubmissionUseCaseProtocol
}
```

Assemble live dependencies at the composition root and pass test doubles for previews and tests.

```swift
let environment = FormSubmissionEnvironment(
    useCase: InMemoryFormSubmissionUseCase()
)
let model = FormSubmissionScreenModel(environment: environment)
```

The machine should own state transitions, not side effects. Use a pure reducer for Observation-driven flows:

```swift
let machine = ObservationDrivenStateMachine(
    initial: .idle,
    canSend: { state, action in
        FormSubmissionExample.canSend(state: state, action: action)
    },
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    }
)
```

The ScreenModel accepts UI actions, invokes the UseCase, and converts its result into a follow-up Action. Views call the ScreenModel and do not know about repositories or API clients. Use `dispatch(_:) ` for fire-and-forget UI input and `send(_:) ` when an explicit committed-state completion point is needed.

For explicit transition enums, see [PlayerExample](../Sources/StateObservationKit/PlayerExample.swift). Its `PlayerEnvironment` injects a `PlayerUseCaseProtocol`, while the concrete `AudioService` stays behind the UseCase boundary.

Use `ObservationDrivenStateMachineMock` for ScreenModel, preview, and state assertion tests. Use the real machine when testing reducer queue ordering and completion semantics.

The runnable minimal example is [FormSubmissionExample](../Sources/StateObservationKit/Examples/FormSubmissionExample.swift). See also [integration_examples.md](integration_examples.md).
