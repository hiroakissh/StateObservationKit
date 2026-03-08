import Foundation

/// Records ordered states for deterministic assertions in tests and previews.
public final class StateSequenceRecorder<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var states: [State] = []

    public init() {}

    public func record(_ state: State) {
        lock.lock()
        defer { lock.unlock() }
        states.append(state)
    }

    public var snapshot: [State] {
        lock.lock()
        defer { lock.unlock() }
        return states
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        states.removeAll()
    }
}
