---
name: state-observation-roadmap
description: StateObservationKit 専用の roadmap-aligned planning, review, and implementation guidance. Use when this repository needs work tied to ROADMAP.md or ROADMAP.ja.md, docs/architecture(.ja).md, Q1 API stabilization, Clean Architecture integration, SwiftUI ergonomics, production tooling, or when docs, samples, tests, and implementation must be aligned as one project-specific change.
---

# StateObservationKit Roadmap Skill

## Workflow

1. Read `AGENTS.md`.
2. Read `ROADMAP.ja.md`. If unavailable, read `ROADMAP.md`.
3. Read `docs/architecture.ja.md`.
4. For Q1 work, read `docs/q1_execution_plan.ja.md`.
5. Load `README.ja.md`, `docs/best_practices.md`, `docs/contributing.md`, `docs/usage.md`, or `docs/integration_examples.md` only when needed.
6. Treat the roadmap and architecture docs as the source of truth for new work, even when implementation still differs.

## Planning

- Classify every task into Q1, Q2, Q3, or Q4 before proposing changes.
- For Q1 tasks, map the work to a milestone and issue ID from `docs/q1_execution_plan.ja.md`.
- State the current gap between roadmap intent and implementation.
- Split work so that each step leaves docs, samples, tests, and API behavior in a coherent state.
- Use `references/phase-checklist.md` and `references/review-checklist.md` as checklists, not as replacement for repo docs.

## Review

- Start with findings that block roadmap alignment or teach the wrong architecture.
- Check terminology drift between `Intent`, `Action`, and `Event`.
- Check that dependency direction remains `View -> StateMachine -> UseCase / Domain -> Infrastructure`.
- Check that sample code shows the recommended architecture, not a shortcut that violates the docs.
- Check that concurrency-sensitive behavior is deterministic and testable.

## Implementation Rules

- Prefer protocol or environment injection over direct references to concrete infrastructure types.
- Keep state changes explicit and exhaustive. Avoid `default` branches when a full `switch` is possible.
- Preserve deterministic reducer and dispatch ordering.
- Guard Observation and SwiftUI integration with conditional compilation.
- When public behavior changes, update docs and examples in the same task.

## Output Expectations

- For planning tasks, return target quarter, milestone or issue mapping, milestone order, dependencies, and validation plan.
- For review tasks, return findings first, then risks or assumptions, then the recommended implementation order.
- For implementation tasks, report which docs, samples, tests, and validations moved together.
