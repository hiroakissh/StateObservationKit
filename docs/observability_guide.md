# Observation Observability and Debugging Guide

`ObservationDrivenStateMachine` can expose not only UI state but also the ordered lifecycle of each Action during development. Observation is kept outside the state mutation path, so reducer queue ordering remains deterministic.

## Event lifecycle

Each Action is traced in this order:

```text
enqueued
   ↓
started
   ↓
committed / rejected
```

- `enqueued`: the Action was added to the ordered queue
- `started`: reducer execution began after preceding work committed
- `committed`: the reducer accepted the Action and published a next State
- `rejected`: `canSend` rejected the Action without changing State

## Recorder

```swift
let recorder = ObservationTraceRecorder<FormSubmissionState, FormSubmissionAction>()

let machine = ObservationDrivenStateMachine(
    initial: .idle,
    canSend: { state, action in
        FormSubmissionExample.canSend(state: state, action: action)
    },
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    },
    traceRecorder: recorder
)

_ = await machine.send(.start)

recorder.snapshot        // ordered lifecycle events
recorder.acceptedActions // committed actions only
recorder.stateSequence   // initial state + committed states
```

`ObservationTraceRecorder` is thread-safe and exposes snapshots. Use `snapshot` to inspect rejected work and exact ordering; use `stateSequence` when you only need committed state assertions.

## Logger

The application owns the logging destination:

```swift
let logger = ObservationTraceLogger { message in
    print("[Form] \(message)")
}

let machine = ObservationDrivenStateMachine(
    initial: .idle,
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    },
    logger: logger
)
```

On Apple platforms, it can use unified logging:

```swift
let logger = ObservationTraceLogger(
    subsystem: "com.example.player",
    category: "state-machine"
)
```

The logger sink runs on the machine's MainActor. Keep it lightweight and hand off expensive work to an asynchronous logging system.

## Debug overlay

When Observation and SwiftUI are available, show the current state, last Action, reducer phase, and pending count:

```swift
let model = TimerExampleScreenModel()

ZStack(alignment: .bottomTrailing) {
    TimerExampleView(model: model)

    ObservationDebugOverlay(machine: model.machine)
        .padding()
}
```

This is a development view. Gate it behind an application debug flag or conditional compilation before shipping it in a release build.

## Production-shaped Timer sample

`TimerExampleScreenModel` and `TimerExampleView` combine:

- explicit timer state transitions through a pure reducer
- a cancellable ticker owned by the Application layer
- ordered state recording with `ObservationTraceRecorder`
- a development display using `ObservationDebugOverlay`

See [TimerExample.swift](../Sources/StateObservationKit/SwiftUIExample/TimerExample.swift). In a production app, inject a Clock or UseCase protocol so time-dependent behavior can be tested without waiting.

Build the SwiftPM sample application from the repository root with `swift build --product StateObservationKitTimerExample`. Its app entry point is [TimerExampleApp.swift](../Examples/TimerApp/TimerExampleApp.swift).

## Testing guidance

- Use the real `ObservationDrivenStateMachine` for queue ordering and commit semantics.
- Use `ObservationDrivenStateMachineMock` for deterministic reducer and ScreenModel assertions.
- Test logger event counts and message shape; the application owns the logging destination.
- Test the overlay's state-specific rendering and keep Action sending inside the View boundary.
