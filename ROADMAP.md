# StateObservationKit Roadmap 2026

[日本語](ROADMAP.ja.md) | [README](README.md) | [Architecture](docs/architecture.md)

This roadmap describes the intended direction of StateObservationKit through 2026. It is meant to communicate project direction and design philosophy, not a strict release contract.

## Vision

StateObservationKit aims to introduce a state-driven application architecture for SwiftUI.

Instead of managing application behavior through scattered flags, callbacks, and ViewModels, the goal is to make state transitions the primary mechanism for controlling business logic.

The framework is designed to:

- Work naturally with SwiftUI Observation
- Fit within Clean Architecture
- Provide a state-machine-based alternative to MVVM
- Remain lighter and simpler than full architecture frameworks such as TCA

## Core Philosophy

StateObservationKit is built around the following principles.

### 1. State is the source of truth

Application behavior should be determined by current state and intent, not scattered conditionals.

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

In the current API, the concept of `Intent` is represented by `Action`.

### 2. State transitions should be explicit

Instead of implicit behavior hidden in callbacks or ViewModels, transitions should be visible, structured, and inspectable.

### 3. Clean Architecture compatibility

State machines belong to the Application layer, not the Domain layer.

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

### 4. SwiftUI-first ergonomics

The framework should feel natural to use from SwiftUI, especially with Observation and `@Bindable`.

### 5. Keep architecture lightweight

The package should avoid unnecessary ceremony, lock-in, and heavyweight abstractions.

## Roadmap Overview

| Quarter | Theme |
| --- | --- |
| 2026 Q1 | Core Architecture Stabilization |
| 2026 Q2 | Clean Architecture Integration |
| 2026 Q3 | SwiftUI Ergonomics and Tooling |
| 2026 Q4 | Production Readiness and Ecosystem |

## 2026 Q1: Core Architecture Stabilization

**Goal**  
Define the core architectural model and stabilize the fundamental APIs.

### Focus Areas

**Core concepts definition**

Introduce a clear vocabulary around:

- State
- Intent
- Transition
- Machine

```text
Intent
  ↓
Transition Decision
  ↓
Effect / UseCase
  ↓
Next State
```

**API simplification**

Refine the API surface of:

- `TransitionDrivenStateMachine`
- `ObservationDrivenStateMachine`

Clarify responsibilities:

| Component | Responsibility |
| --- | --- |
| State | Represents application state |
| Intent | Represents user or system input |
| Transition | Represents a meaningful state change |
| Machine | Interprets input and executes transitions |

**Documentation**

Publish foundational documentation:

- Architecture overview
- MVVM vs TCA vs StateObservationKit
- When to use state machines

### Deliverables

- Updated README
- Architecture diagrams
- Concept documentation

## 2026 Q2: Clean Architecture Integration

**Goal**  
Make StateObservationKit fit naturally into Clean Architecture projects.

### Focus Areas

**Dependency injection**

Introduce environment-based dependency management.

```swift
struct PlayerEnvironment {
    let audioService: AudioServiceProtocol
}
```

Machines should not directly reference infrastructure implementations.

**UseCase integration**

Provide patterns for connecting machines to UseCases.

```text
Intent
  ↓
Machine
  ↓
UseCase
  ↓
Next State
```

**Layer separation guide**

Publish guidance on the responsibility of each layer:

| Layer | Responsibility |
| --- | --- |
| Domain | Business rules |
| Application | State machines |
| Infrastructure | External dependencies |
| UI | Rendering and user interaction |

### Deliverables

- Clean Architecture integration examples
- Dependency injection support
- UseCase integration patterns

## 2026 Q3: SwiftUI Ergonomics and Tooling

**Goal**  
Make the framework extremely comfortable to use in SwiftUI applications.

### Focus Areas

**SwiftUI integration**

Improve SwiftUI ergonomics with:

- `@Bindable` machine support
- Intent sending helpers
- Binding generation
- SwiftUI-friendly state access

```swift
@Bindable var machine: PlayerMachine

Button("Play") {
    machine.send(.playTapped)
}
```

**Intent availability**

Expose operation availability.

```swift
machine.canSend(.pauseTapped)
```

This enables natural button disabling and control-state rendering in SwiftUI.

**UI projection**

Introduce optional UI projection layers.

```text
Domain State
   ↓
Presentation Projection
   ↓
SwiftUI View
```

This keeps UI-specific concerns from leaking into domain-facing state.

### Deliverables

- SwiftUI integration utilities
- Intent availability checks
- UI projection patterns

## 2026 Q4: Production Readiness and Ecosystem

**Goal**  
Prepare the framework for real-world production adoption.

### Focus Areas

**Transition recording**

Introduce transition history tracking.

```text
Intent
 ↓
Transition
 ↓
State Change
 ↓
Recorded Event
```

Possible uses:

- Debugging
- Analytics
- Testing
- Time-travel debugging

Example:

```text
Idle
 ↓ startTapped
Running
 ↓ pauseTapped
Paused
```

**Debugging tools**

Provide debugging utilities:

- Transition logger
- State change tracing
- Development debug overlays

**Example applications**

Create production-style examples:

| Example | Purpose |
| --- | --- |
| Timer App | Canonical state machine example |
| Coffee Brew Flow | Multi-step workflow |
| Authentication Flow | Real application lifecycle |
| Form Submission | Async state transitions |

**Testing tools**

Expand testing support:

- Transition assertions
- Intent history
- State sequence testing

### Deliverables

- Transition recorder
- Debugging utilities
- Example applications
- Testing helpers

## Long-Term Vision

StateObservationKit aims to establish a state-driven application architecture for SwiftUI.

The goal is not to replace existing frameworks, but to provide a clear alternative for teams who want:

- Explicit state transitions
- Strong business logic control
- SwiftUI-friendly APIs
- Clean Architecture compatibility
- Lightweight architecture

## Guiding Principles

StateObservationKit will intentionally avoid:

**Overly complex abstractions**  
Keep the API simple and predictable.

**Architecture lock-in**  
Developers should remain free to structure projects as needed.

**Heavy ceremony**  
Avoid excessive boilerplate or framework-specific rituals.

## Project Goals for 2026

By the end of 2026, StateObservationKit aims to:

- Establish a stable state-machine-based architecture
- Provide SwiftUI-first developer ergonomics
- Demonstrate production use cases
- Offer strong debugging and testing support
- Present a clear alternative to MVVM for state-driven applications
