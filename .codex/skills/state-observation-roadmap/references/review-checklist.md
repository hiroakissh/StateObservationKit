# Review Checklist

## Terminology

- Is `Intent`, `Action`, and `Event` usage consistent?
- If architecture language uses `Intent`, does the public API still describe `Action` correctly?

## Architecture

- Does the dependency direction remain `View -> StateMachine -> UseCase / Domain -> Infrastructure`?
- Is a machine directly referencing infrastructure that should be injected?
- Does sample code teach the intended architecture?

## API and Behavior

- Is the machine boundary still the only place where state changes are committed?
- Are invalid transitions, follow-up transitions, and error behavior explicit?
- Does the API preserve deterministic ordering for concurrent or async paths?

## Docs and Samples

- Do README, roadmap, architecture docs, usage docs, and samples agree?
- Do examples compile against the current API in principle?
- Is aspirational behavior marked as such when it is not implemented yet?

## Tests

- Do tests cover invalid transitions, effect failures, ordering, and mocks?
- Is a test relying on arbitrary `sleep` where a deterministic completion signal should exist?
- If public behavior changed, was the validation command updated accordingly?
