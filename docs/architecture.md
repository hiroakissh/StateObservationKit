# Architecture

[日本語](architecture.ja.md) | [README](../README.md) | [Roadmap](../ROADMAP.md)

StateObservationKit is designed as an Application-layer state-machine library for SwiftUI projects. It does not try to become a full application framework, and it does not require a single project structure. Its role is narrower and more explicit: coordinate state transitions, expose state to UI, and keep side effects at clear boundaries.

## Architectural Model

The core model is intentionally small:

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

In the current API, the architectural concept of `Intent` is represented by `Action`.
In this document, `Intent` is the architecture term, while `Action` / `ActionType` refers to the current public API surface.

| Concept | Current API | Role |
| --- | --- | --- |
| State | `StateType` | Represents the current application state |
| Intent | `ActionType` | Represents user or system input |
| Transition | `TransitionType` | Defines a meaningful state change and optional side effect |
| Machine | `TransitionDrivenStateMachine` / `ObservationDrivenStateMachine` | Interprets input and commits state changes |

## Layer Placement

StateObservationKit is intended to live in the Application layer.

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

This placement is deliberate:

- Views render state and emit input
- State machines coordinate flow and make transition decisions
- UseCases and domain services execute business operations
- Infrastructure handles I/O, persistence, networking, and platform APIs

## Responsibilities by Layer

| Layer | Responsibility | Typical contents |
| --- | --- | --- |
| UI / View | Render state and send user input | SwiftUI views, bindings, navigation triggers |
| Application State Machine | Orchestrate state transitions and workflow | `TransitionDrivenStateMachine`, `ObservationDrivenStateMachine` |
| UseCase / Domain | Execute business rules and domain operations | UseCases, domain services, entities, validation rules |
| Infrastructure | Talk to the outside world | Repositories, API clients, storage, clocks, system services |

StateObservationKit does not force one strict Clean Architecture interpretation. Some teams place UseCases in the Application layer, while others separate them more explicitly from Domain. The important rule is that the state machine should not directly become the infrastructure boundary.

## Two Machine Styles

| Type | Best for | Characteristics |
| --- | --- | --- |
| `TransitionDrivenStateMachine` | Explicit orchestration and business-flow control | Strongly typed transitions, optional async effects, invalid transition handling |
| `ObservationDrivenStateMachine` | SwiftUI-facing state and reactive UI updates | Observation-friendly state exposure, serialized reducer execution, `@Bindable` integration |

Both machine styles can share the same domain model. The package is intended to let teams choose the amount of structure they need without rewriting the whole application model.

## Current Dispatch Semantics

### `TransitionDrivenStateMachine`

- Resolves a transition from the current `(state, action)` pair or throws `TransitionDispatchError.invalidTransition`.
- Runs `effect` before committing state.
- Preserves the current state when `effect` fails.
- Applies a follow-up `Action` only after the current transition has been committed.

### `ObservationDrivenStateMachine`

- Accepts input through `dispatch(_:)` and returns immediately.
- Serializes reducer execution internally to preserve dispatch order.
- Publishes the resulting state after each reducer run completes on the main actor.
- Currently exposes no completion handle or rejection result for a dispatched action.

## Integration Rules

### 1. Change state through `dispatch(_:)`

State changes should go through the machine boundary. This keeps transitions observable, testable, and easier to reason about.

### 2. Delegate side effects to UseCases

State machines should decide when work happens, but external work should live behind UseCases, services, or repositories.

### 3. Inject dependencies through abstractions

Prefer protocols or environment structs over concrete infrastructure references inside the machine.

```swift
struct PlayerEnvironment {
    let audioService: AudioServiceProtocol
}
```

### 4. Separate UI projection when needed

If UI-specific formatting or selection logic starts polluting domain-facing state, add a presentation projection layer.

```text
Domain State
   ↓
Presentation Projection
   ↓
SwiftUI View
```

### 5. Keep test doubles protocol-based

`ObservationStateMachineType` and `ObservationDrivenStateMachineMock` exist so UI and application code can depend on abstractions instead of concrete runtime behavior.

## SwiftUI Ergonomics

StateObservationKit is intentionally SwiftUI-first where the platform allows it:

- Use Observation when available
- Support `@Bindable`-friendly usage
- Keep state reads simple in the View layer
- Preserve deterministic ordering by serializing reducer execution

The goal is not to recreate ViewModel-heavy patterns under a different name. The goal is to let the View observe a machine that exposes state directly and accepts explicit input.

## What the Project Avoids

StateObservationKit intentionally avoids:

- Heavy framework ceremony
- Hidden control flow
- Mandatory architecture lock-in
- Large macro or DSL surfaces for basic state changes

This is what makes it a practical alternative for teams that want more explicit state management than MVVM, without adopting a full framework ecosystem.

## Relationship to the Roadmap

The current architecture establishes the baseline. The roadmap expands it in four directions:

- Stronger concept documentation and API stabilization
- Better Clean Architecture integration and dependency injection
- Better SwiftUI ergonomics and intent availability
- Production tooling such as transition recording and debugging utilities

During Q1 stabilization, treat the roadmap as the target direction and the README plus tests as the source for the current public contract.
If they differ, the gap should be handled as planned migration work.

See [ROADMAP.md](../ROADMAP.md) for the detailed plan.
