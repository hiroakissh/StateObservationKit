# Phase Checklist

## Q1 Core Architecture Stabilization

- Clarify the vocabulary for State, Intent, Transition, and Machine.
- Reduce API ambiguity before adding new surface area.
- Keep README, roadmap, architecture, usage docs, and samples consistent.
- Ensure docs examples match the public API or explicitly state that they are aspirational.

## Q2 Clean Architecture Integration

- Keep machines out of the infrastructure boundary.
- Introduce protocol or environment-based dependency injection.
- Show UseCase integration in docs and samples.
- Preserve freedom of project structure and avoid framework lock-in.

## Q3 SwiftUI Ergonomics and Tooling

- Improve `@Bindable`-friendly usage and state access.
- Add intent availability or send helpers only if they stay lightweight.
- Keep UI projection optional and isolated from domain-facing state.
- Verify SwiftUI examples reflect the preferred integration path.

## Q4 Production Readiness and Ecosystem

- Add transition recording without obscuring control flow.
- Prefer thin debugging utilities over heavy runtime frameworks.
- Add testing helpers that improve determinism and sequence assertions.
- Treat sample apps as production-style examples, not toy demos.
