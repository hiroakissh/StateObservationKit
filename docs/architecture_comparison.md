# Architecture Comparison (MVVM / TCA / StateObservationKit)

StateObservationKit is not intended to replace every architecture.

It is a strong fit when teams want to:

- make state transitions explicit
- keep the architecture lightweight
- map design decisions directly into implementation
- keep testability without heavy framework overhead

---

## High-level Comparison

| Architecture | Strength | Weakness | Best fit |
|---|---|---|---|
| MVVM | Easy to start | Responsibilities tend to accumulate in ViewModel | Small and simple screens |
| TCA | Strong consistency and testability | Boilerplate and learning cost can be high | Large, long-lived applications |
| StateObservationKit | Explicit transitions with lightweight structure | Requires state-machine-first design thinking | Teams that need structure without full framework weight |

---

## Design Center

| Architecture | Design center |
|---|---|
| MVVM | ViewModel |
| TCA | Reducer / Store |
| StateObservationKit | StateMachine / Transition |

StateObservationKit puts **state transitions themselves** at the center of design.

---

## Responsibility Comparison

| Concern | MVVM | TCA | StateObservationKit |
|---|---|---|---|
| UI rendering | View | View | View |
| UI interaction entry | ViewModel | Store / Reducer | ScreenModel / Action |
| State transitions | Often implicit in ViewModel | Reducer | StateMachine |
| Side effects | Often mixed in ViewModel/UseCase | Effect / Dependency | UseCase |
| Design traceability | Weak | Strong | Strong |
| Boilerplate | Low at first, often grows later | High | Medium to low |

---

## Comparison Diagrams

### MVVM

```mermaid
flowchart LR
    U[User] --> V[View]
    V --> VM[ViewModel]
    VM --> V
    VM --> UC[UseCase]
```

- Easy to start
- Fast for small features
- Responsibilities often drift into ViewModel

### TCA

```mermaid
flowchart LR
    U[User] --> V[View]
    V --> S[Store]
    S --> R[Reducer]
    R --> ST[State]
    ST --> V
    R --> EF[Effect]
    EF --> S
```

- Very strong consistency
- Rich ecosystem
- More concepts and boilerplate

### StateObservationKit

```mermaid
flowchart LR
    U[User] --> V[View]
    V --> A[Action]
    A --> SM[StateMachine]
    SM --> T[Transition]
    T --> S[Next State]
    S --> V

    SM --> E[Side Effect]
    E --> UC[UseCase]
    UC --> SE[System Event]
    SE --> SM
```

- Explicit transitions
- Keeps View thin
- Keeps side effects outside StateMachine
- Maps architecture naturally to implementation

---

## How to Choose

### Choose MVVM when

- the feature is small
- transition complexity is low
- implementation speed matters most

### Choose TCA when

- the application is large and long-lived
- strict team-wide consistency is required
- you want the full ecosystem of tooling and patterns

### Choose StateObservationKit when

- you want architecture to remain visible in code
- features can be modeled as state + transition
- you want something lighter than TCA
- you want to avoid large ViewModels

---

## One-sentence Summary

| Architecture | Summary |
|---|---|
| MVVM | Center logic around ViewModels |
| TCA | Center state change around Reducers and Stores |
| StateObservationKit | Center design around StateMachines and Transitions |

---

## Philosophy Difference

- MVVM asks: where should UI logic live?
- TCA asks: how should state changes be managed consistently?
- StateObservationKit asks: how can architectural design become executable in code?

---

## Conclusion

StateObservationKit is not universally best for every case.

It is best suited to this goal:

**Keep state-driven architecture explicit, lightweight, and directly implementable.**
