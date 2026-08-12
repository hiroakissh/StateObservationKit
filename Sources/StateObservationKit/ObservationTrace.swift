import Foundation

/// The lifecycle phase represented by an Observation-driven trace event.
public enum ObservationTracePhase: String, Sendable {
    case enqueued
    case started
    case committed
    case rejected
}

/// An ordered, immutable record of work performed by an Observation-driven machine.
///
/// `state` is the state observed at the phase. For a `.committed` event,
/// `nextState` contains the state produced by the reducer. Other phases leave
/// `nextState` as `nil`.
public struct ObservationTraceEvent<State: Sendable, Action: Sendable>: Sendable {
    public let sequence: UInt64
    public let phase: ObservationTracePhase
    public let action: Action
    public let state: State
    public let nextState: State?
    public let pendingActionCount: Int

    public init(
        sequence: UInt64,
        phase: ObservationTracePhase,
        action: Action,
        state: State,
        nextState: State? = nil,
        pendingActionCount: Int
    ) {
        self.sequence = sequence
        self.phase = phase
        self.action = action
        self.state = state
        self.nextState = nextState
        self.pendingActionCount = pendingActionCount
    }

    /// A compact message suitable for a development logger.
    public var message: String {
        var message = "[\(sequence)] \(phase.rawValue) action=\(String(describing: action)) state=\(String(describing: state))"
        if let nextState {
            message += " next=\(String(describing: nextState))"
        }
        message += " pending=\(pendingActionCount)"
        return message
    }
}

/// A thread-safe recorder for Observation-driven state transitions.
public final class ObservationTraceRecorder<State: Sendable, Action: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var initialState: State?
    private var events: [ObservationTraceEvent<State, Action>] = []

    public init() {}

    public func recordInitialState(_ state: State) {
        lock.lock()
        defer { lock.unlock() }

        guard initialState == nil else { return }
        initialState = state
    }

    public func record(_ event: ObservationTraceEvent<State, Action>) {
        lock.lock()
        defer { lock.unlock() }

        if initialState == nil {
            initialState = event.state
        }
        events.append(event)
    }

    public var snapshot: [ObservationTraceEvent<State, Action>] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public var committedEvents: [ObservationTraceEvent<State, Action>] {
        snapshot.filter { $0.phase == .committed }
    }

    public var acceptedActions: [Action] {
        committedEvents.map(\.action)
    }

    public var stateSequence: [State] {
        lock.lock()
        defer { lock.unlock() }

        guard let initialState else {
            return events.first.map { [$0.state] } ?? []
        }

        return [initialState] + events.compactMap { event in
            guard event.phase == .committed else { return nil }
            return event.nextState
        }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        initialState = nil
        events.removeAll()
    }
}

/// Sends formatted trace events to an application-owned logging sink.
/// Keep the sink lightweight because it is invoked on the machine's MainActor.
public struct ObservationTraceLogger: Sendable {
    private let sink: @Sendable (String) -> Void

    public init(sink: @escaping @Sendable (String) -> Void) {
        self.sink = sink
    }

    public func log<State: Sendable, Action: Sendable>(
        _ event: ObservationTraceEvent<State, Action>
    ) {
        sink(event.message)
    }
}

#if canImport(os)
import os

public extension ObservationTraceLogger {
    /// Creates a logger backed by the platform unified logging system.
    init(subsystem: String, category: String) {
        let logger = Logger(subsystem: subsystem, category: category)
        self.init { message in
            logger.debug("\(message, privacy: .public)")
        }
    }
}
#endif

/// The values most useful to a development-only state debug overlay.
public struct ObservationDebugSnapshot<State: Sendable, Action: Sendable>: Sendable {
    public let state: State
    public let pendingActionCount: Int
    public let lastAction: Action?
    public let lastPhase: ObservationTracePhase?

    public init(
        state: State,
        pendingActionCount: Int,
        lastAction: Action?,
        lastPhase: ObservationTracePhase?
    ) {
        self.state = state
        self.pendingActionCount = pendingActionCount
        self.lastAction = lastAction
        self.lastPhase = lastPhase
    }
}
