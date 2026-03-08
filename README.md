# StateObservationKit

[日本語](README.ja.md) | [Roadmap](ROADMAP.md) | [ロードマップ](ROADMAP.ja.md) | [Architecture](docs/architecture.md) | [アーキテクチャ](docs/architecture.ja.md)

StateObservationKit is a lightweight state-machine toolkit for building state-driven application architecture in SwiftUI. It combines Swift Concurrency and SwiftUI Observation so that transitions stay explicit, side effects stay controlled, and UI integration stays natural.

## Vision

StateObservationKit aims to make state transitions the primary mechanism for application behavior.

Instead of spreading business rules across flags, callbacks, and ad-hoc ViewModels, the package encourages a simple model:

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

In the current API, the architectural idea of an `Intent` is represented by `Action`.
In this document, `Intent` refers to the architecture concept, while code examples use `Action` / `ActionType` for the current public API.

## Core Philosophy

- State is the source of truth.
- Transitions should be explicit and inspectable.
- State machines belong to the Application layer and coordinate UseCases.
- SwiftUI ergonomics should feel natural with Observation and `@Bindable`.
- The package should remain lighter and simpler than full architecture frameworks.

## Layer Placement

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

StateObservationKit is intended to live in the Application layer. It owns flow control and state changes, while side effects and external dependencies stay behind UseCases or other boundaries.

## What the Package Provides

| Type | Purpose | Typical use |
| --- | --- | --- |
| `TransitionDrivenStateMachine` | Makes transitions and effects explicit with strongly typed `enum` definitions. | Application flows, orchestration, business logic control |
| `ObservationDrivenStateMachine` | Publishes state reactively for UI layers and serializes reducer execution. | SwiftUI-facing state machines, Observation integration, UI availability checks, and projection-driven views |
| `ObservationDrivenStateMachineMock` | Replaces async behavior with deterministic synchronous state changes for tests. | Unit tests, UI tests, previews |
| `TransitionRecorder` | Records committed transitions, actions, and state sequences in order. | Transition history assertions, debugging, follow-up action tracing |
| `StateSequenceRecorder` | Records arbitrary state snapshots with a lightweight API. | Hook-based state sequence assertions, previews, simple tracing |

## Concept Mapping

| Architectural concept | Current API | Responsibility |
| --- | --- | --- |
| State | `StateType` | Represents the current application state |
| Intent | `ActionType` | Represents user or system input |
| Transition | `TransitionType` | Defines a meaningful state change and its optional effect |
| Machine | `TransitionDrivenStateMachine` / `ObservationDrivenStateMachine` | Interprets input, executes transitions, and exposes state |

## Current Status And Reading Order

StateObservationKit is being realigned toward the roadmap and architecture documents. That means some documentation describes the target direction while the current implementation still reflects an earlier API shape.

Use this reading order when you need to decide what to trust:

1. `ROADMAP.md` for project direction and target architecture
2. `docs/architecture.md` for design boundaries and dependency direction
3. This README for the current public API contract
4. Inline type documentation and tests for current runtime behavior

If the roadmap and current implementation differ, treat that gap as an active migration target, not as a documentation mistake.

## Current Machine Contract

### `TransitionDrivenStateMachine`

- `dispatch(_:)` is the only public entry point for committing state changes.
- If the current `(state, action)` pair does not match a transition, the machine throws `TransitionDispatchError.invalidTransition` and leaves state unchanged.
- The machine runs a transition's `effect` before committing `state`.
- If the `effect` throws a non-cancellation error, the machine leaves state unchanged and throws `TransitionDispatchError.effectFailed`.
- If the `effect` returns a follow-up `Action`, the machine commits the current transition first and then dispatches the follow-up action from the new state.
- When you pass a `transitionRecorder`, the machine records only committed transitions. Invalid transitions and effect failures do not pollute the history.

### `ObservationDrivenStateMachine`

- `dispatch(_:)` returns immediately and schedules reducer execution asynchronously.
- `send(_:)` enqueues work on the same ordered queue and returns after the resulting state has been published.
- `canSend(_:)` returns a conservative UI-facing availability check based on the published state and whether reducer work is still pending.
- Reducer execution is serialized on an ordered internal queue, so `dispatch(_:)` and `send(_:)` are applied in call order.
- `state` is updated on the main actor after each reducer run completes.
- `dispatch(_:)` remains the fire-and-forget API; use `send(_:)` when tests or orchestration code need an explicit completion point.

## Example: Explicit Transitions

```swift
enum PlayerState: StateType {
    case idle
    case playing
    case paused
}

enum PlayerAction: ActionType {
    case play
    case pause
}

enum PlayerTransition: TransitionType {
    typealias State = PlayerState
    typealias Action = PlayerAction

    case idlePlay
    case playingPause

    var from: PlayerState {
        switch self {
        case .idlePlay: return .idle
        case .playingPause: return .playing
        }
    }

    var action: PlayerAction {
        switch self {
        case .idlePlay: return .play
        case .playingPause: return .pause
        }
    }

    var to: PlayerState {
        switch self {
        case .idlePlay: return .playing
        case .playingPause: return .paused
        }
    }

    var effect: (@Sendable () async throws -> PlayerAction?)? { nil }
}

let machine = TransitionDrivenStateMachine<PlayerTransition>(initial: .idle)
try await machine.dispatch(.play)
print(await machine.state) // playing
```

`dispatch(_:)` is the only entry point for state changes. If an effect returns a follow-up `Action`, the machine dispatches it after the current transition has been committed.

As a thin Q4 production/testing utility, `TransitionRecorder` and `StateSequenceRecorder` let you inspect committed history without changing control flow:

```swift
let transitions = TransitionRecorder<PlayerTransition>()
let states = StateSequenceRecorder<PlayerState>()

let machine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { states.record($0) },
    transitionRecorder: transitions
)

try await machine.dispatch(.play)

print(transitions.actions)       // [.play]
print(transitions.stateSequence) // [.idle, .playing]
print(states.snapshot)           // [.idle, .playing]
```

Because `TransitionRecorder` records only committed state changes, tests that involve failing effects can assert the confirmed history directly.

## Example: Observation-Friendly State

```swift
let machine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
    initial: .idle,
    canSend: { state, action in
        switch (state, action) {
        case (.idle, .play), (.playing, .pause), (.paused, .play):
            return true
        default:
            return false
        }
    }
) { state, action in
    switch (state, action) {
    case (.idle, .play):
        state = .playing
    case (.idle, .pause):
        break
    case (.playing, .play):
        break
    case (.playing, .pause):
        state = .paused
    case (.paused, .play):
        state = .playing
    case (.paused, .pause):
        break
    }
}

let committedState = await machine.send(.play)
print(committedState) // playing
```

On platforms that support Observation, the machine can be used naturally from SwiftUI:

```swift
struct PlayerView: View {
    @Bindable var machine: ObservationDrivenStateMachine<PlayerState, PlayerAction>

    var body: some View {
        let viewState = machine.project(PlayerControls.init)

        VStack {
            Text("\(String(describing: machine.state))")
            Button(viewState.primaryTitle) {
                Task {
                    _ = await machine.send(viewState.primaryAction)
                }
            }
                .disabled(!machine.canSend(viewState.primaryAction))
        }
    }
}

struct PlayerControls {
    let primaryTitle: String
    let primaryAction: PlayerAction

    init(state: PlayerState) {
        switch state {
        case .idle, .paused:
            self.primaryTitle = "Play"
            self.primaryAction = .play
        case .playing:
            self.primaryTitle = "Pause"
            self.primaryAction = .pause
        }
    }
}
```

When a control needs a `Binding`, use `binding(_:send:)` to map value changes back into actions.

```swift
TextField(
    "Title",
    text: machine.binding(\.draftTitle, send: EditorAction.titleChanged)
)
```

The snippet above is the smallest possible example, so the View talks to the machine directly. In the package sample, SwiftUI input goes through a ScreenModel-style `send(_:)` method first, and that wrapper decides when to call `dispatch(_:)`. Use that shape when side effects, `Result` handling, or follow-up actions should stay out of the View.

## Documentation

- [Roadmap](ROADMAP.md)
- [Architecture](docs/architecture.md)
- [Japanese README](README.ja.md)
- [Japanese roadmap](ROADMAP.ja.md)
- [Japanese architecture document](docs/architecture.ja.md)

## 2026 Roadmap Snapshot

| Quarter | Focus |
| --- | --- |
| 2026 Q1 | Core architecture stabilization |
| 2026 Q2 | Clean Architecture integration |
| 2026 Q3 | SwiftUI ergonomics and tooling |
| 2026 Q4 | Production readiness and ecosystem |

See [ROADMAP.md](ROADMAP.md) for the detailed plan and guiding principles.

## Testing

```bash
swift test
swift build -Xswiftc -strict-concurrency=complete
```

Where Observation and SwiftUI are available, the sample UI integration is also validated as part of the package build.

## Platform Support

- iOS 17+
- macOS 14+

## License

See [LICENSE](LICENSE).
