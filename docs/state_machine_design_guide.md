# StateMachine Design Guide

This document defines **StateMachine design rules** for StateObservationKit.

Goals:

- keep state design consistent
- keep transitions readable
- keep design testable

---

## 1. State Design Rules

State represents the **system state**.

Do not model raw UI toggles as state names; model semantic system states.

### GOOD

- `idle`
- `loading`
- `loaded`
- `failed`

### BAD

- `showSpinner`
- `showErrorLabel`

UI presentation should be derived in View.

---

## 2. State Anti-patterns

### 2.1 Boolean Explosion

#### BAD

- `isLoading`
- `hasError`
- `hasData`
- `isEmpty`

These combinations create invalid/ambiguous states.

#### GOOD

- `idle`
- `loading`
- `loaded`
- `failed`
- `empty`

### 2.2 Data-driven State

#### BAD

- infer state only from `items: [Item]`

#### GOOD

- `loading`
- `loaded(items)`
- `empty`

### 2.3 UI-driven State

#### BAD

- `showPaywall`
- `showLogin`

UI is a result of state, not the state itself.

#### GOOD

- `unauthorized`
- `premiumRequired`

### 2.4 Mega State

#### BAD

- put rendering/transition/control in one generic state like `ready`

#### GOOD

- `idle`
- `editing`
- `saving`
- `completed`

---

## 3. Transition Rules

Define transitions as:

`Current State + Action + Guard -> Next State`

> Public API wording should prioritize `Action` / `ActionType`.

### Make guard conditions explicit

- `loaded + purchaseTapped` and `user == premium` -> `purchasing`
- `loaded + purchaseTapped` and `user == free` -> `paywall`

### Manage transitions in a table

| Current | Action | Guard | Next |
|---|---|---|---|
| idle | onAppear | | loading |
| loading | loadSucceeded | | loaded |
| loading | loadFailed | | failed |

This keeps tests, implementation, and spec aligned.

---

## 4. SideEffect Rules

Keep side effects **outside** the StateMachine.

- StateMachine: transition control
- UseCase: side-effect execution

### GOOD

`loading -> fetchItems() -> loadSucceeded`

### BAD

Implement API call details directly inside StateMachine.

---

## 5. Variation Rules

Classify variations into three types:

| Type | Example |
|---|---|
| User | free / premium |
| State | first launch / empty data |
| Environment | offline |

Decide where each variation is handled:

1. Transition Guard
2. State
3. View

---

## 6. StateMachine Principles

1. StateMachine is responsible for transitions
2. Action represents events
3. State represents system state
4. Side effects live in UseCase

---

## 7. Testing Rules

Use three test groups:

| Type | Focus |
|---|---|
| State Test | transition behavior |
| Variation Test | variation branches |
| Effect Test | side-effect results |

### State Test

- Given `idle`
- When `onAppear`
- Then `loading`

### Variation Test

- Given `free user`
- When `purchaseTapped`
- Then `paywall`

### Effect Test

- `fetchItems` success -> `loadSucceeded`
- `fetchItems` failure -> `loadFailed`

---

## 8. Design Goal

Align the chain below end-to-end:

`Design -> State -> Transition -> Test -> Implementation`

The key is minimizing drift between architecture and code.

---

## 9. Minimal Flow

```text
User
 ↓
Action
 ↓
StateMachine
 ↓
Transition
 ↓
State
 ↓
View
```

---

## 10. StateMachine Architecture Overview

### 10.1 System flow

```mermaid
flowchart TD
    U[User] --> A[User Action]
    A --> SM[ScreenModel / Feature Entry]
    SM --> TM[StateMachine]
    TM --> TR[Transition Rule]
    TR --> NS[Next State]
    NS --> V[SwiftUI View]

    TM --> SE[Side Effect Trigger]
    SE --> UC[UseCase / Domain Logic]
    UC --> EV[System Event]
    EV --> TM
```

### 10.2 Layer responsibilities

```mermaid
flowchart LR
    subgraph UI[UI Layer]
        V[SwiftUI View]
    end

    subgraph APP[Application Layer]
        SM[ScreenModel]
        TM[StateMachine]
        TR[Transition]
    end

    subgraph DOMAIN[Domain Layer]
        UC[UseCase]
    end

    V -->|send action| SM
    SM -->|forward event| TM
    TM --> TR
    TR --> TM
    TM -->|publish state| V
    TM -->|trigger side effect| UC
    UC -->|return system event| TM
```

### 10.3 Transition core shape

```mermaid
flowchart LR
    CS[Current State]
    AC[Action]
    GD{Guard Condition}
    NS[Next State]

    CS --> GD
    AC --> GD
    GD -->|true| NS
    GD -->|false| XX[No Transition / Another Transition]
```

### 10.4 Design-to-implementation mapping

```mermaid
flowchart TD
    D1[Feature meaning]
    D2[Responsibility definition]
    D3[Variation design]
    D4[State design]
    D5[Action design]
    D6[Transition design]
    D7[SideEffect design]
    D8[Test case design]

    I1[SwiftUI View]
    I2[ScreenModel]
    I3[Feature.State]
    I4[Feature.Action]
    I5[StateMachine]
    I6[UseCase]
    I7[Test Code]

    D1 --> I1
    D2 --> I2
    D3 --> I5
    D4 --> I3
    D5 --> I4
    D6 --> I5
    D7 --> I6
    D8 --> I7
```

### 10.5 Traceability to tests

```mermaid
flowchart TD
    PAT[Pattern ID]
    TR[Transition ID]
    EF[Effect ID]

    TC1[Test Case: Variation Test]
    TC2[Test Case: State Transition Test]
    TC3[Test Case: Side Effect Test]

    PAT --> TC1
    TR --> TC2
    EF --> TC3
```

### 10.6 Responsibility split on one page

```mermaid
flowchart LR
    U[User]
    V[View]
    A[Action]
    SM[StateMachine]
    T[Transition]
    S[State]
    E[Effect]
    UC[UseCase]
    SE[System Event]

    U --> V
    V --> A
    A --> SM
    SM --> T
    T --> S
    S --> V
    SM --> E
    E --> UC
    UC --> SE
    SE --> SM
```

### 10.7 What this diagram communicates

- The View renders State and sends Actions
- The StateMachine owns state transitions
- The UseCase owns side effects
- System Events route async results back into the StateMachine
- State / Action / Transition / Effect defined during design map directly into implementation and tests

### 10.8 One-sentence design summary

StateObservationKit prioritizes **reflecting designed state transitions directly in implementation and tests**.
