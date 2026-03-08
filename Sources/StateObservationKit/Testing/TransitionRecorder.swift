import Foundation

/// Records committed transition events so tests and debug tooling can inspect ordered history.
public final class TransitionRecorder<T: TransitionType>: @unchecked Sendable {
    private let lock = NSLock()
    private var initialState: T.State?
    private var records: [TransitionRecord<T>] = []

    public init() {}

    public func recordInitialState(_ state: T.State) {
        lock.lock()
        defer { lock.unlock() }

        guard initialState == nil else {
            return
        }

        initialState = state
    }

    public func record(_ record: TransitionRecord<T>) {
        lock.lock()
        defer { lock.unlock() }

        if initialState == nil {
            initialState = record.fromState
        }

        records.append(record)
    }

    public var snapshot: [TransitionRecord<T>] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    public var transitions: [T] {
        snapshot.map(\.transition)
    }

    public var actions: [T.Action] {
        snapshot.map(\.action)
    }

    public var followUpActions: [T.Action] {
        snapshot.compactMap(\.followUpAction)
    }

    public var stateSequence: [T.State] {
        lock.lock()
        defer { lock.unlock() }

        guard let initialState else {
            return records.first.map { [$0.fromState] } ?? []
        }

        return [initialState] + records.map(\.toState)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        initialState = nil
        records.removeAll()
    }
}
