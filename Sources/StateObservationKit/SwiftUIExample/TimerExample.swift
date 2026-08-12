#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

public enum TimerExampleState: StateType {
    case idle
    case running(remainingSeconds: Int)
    case paused(remainingSeconds: Int)
    case completed
}

public enum TimerExampleAction: ActionType {
    case start(duration: Int)
    case pause
    case resume
    case tick
    case reset
}

public enum TimerExample {
    public static func canSend(
        state: TimerExampleState,
        action: TimerExampleAction
    ) -> Bool {
        switch (state, action) {
        case (.idle, .start):
            return true
        case (.running, .pause):
            return true
        case (.running(remainingSeconds: let seconds), .tick):
            return seconds > 0
        case (.paused, .resume):
            return true
        case (.running, .reset), (.paused, .reset), (.completed, .reset):
            return true
        case (.idle, _), (.paused, .start), (.paused, .pause), (.paused, .tick),
             (.running, .start), (.running, .resume), (.completed, _):
            return false
        }
    }

    public static func reduce(
        state: inout TimerExampleState,
        action: TimerExampleAction
    ) {
        switch state {
        case .idle:
            switch action {
            case .start(let duration):
                state = .running(remainingSeconds: max(1, duration))
            case .pause, .resume, .tick, .reset:
                break
            }

        case .running(let remainingSeconds):
            switch action {
            case .pause:
                state = .paused(remainingSeconds: remainingSeconds)
            case .tick:
                if remainingSeconds <= 1 {
                    state = .completed
                } else {
                    state = .running(remainingSeconds: remainingSeconds - 1)
                }
            case .start, .resume:
                break
            case .reset:
                state = .idle
            }

        case .paused(let remainingSeconds):
            switch action {
            case .resume:
                state = .running(remainingSeconds: remainingSeconds)
            case .reset:
                state = .idle
            case .start, .pause, .tick:
                break
            }

        case .completed:
            switch action {
            case .reset:
                state = .idle
            case .start, .pause, .resume, .tick:
                break
            }
        }
    }
}

@Observable
@MainActor
/// A small production-shaped sample: an injected machine, deterministic reducer,
/// ordered trace recorder, and a cancellable ticker owned by the application layer.
public final class TimerExampleScreenModel {
    @ObservationIgnored
    public let machine: ObservationDrivenStateMachine<TimerExampleState, TimerExampleAction>
    @ObservationIgnored
    public let traceRecorder: ObservationTraceRecorder<TimerExampleState, TimerExampleAction>

    private let duration: Int
    private var timerTask: Task<Void, Never>?

    public init(
        duration: Int = 25,
        logger: ObservationTraceLogger? = nil
    ) {
        self.duration = max(1, duration)
        let recorder = ObservationTraceRecorder<TimerExampleState, TimerExampleAction>()
        self.traceRecorder = recorder
        self.machine = ObservationDrivenStateMachine(
            initial: .idle,
            canSend: { state, action in
                TimerExample.canSend(state: state, action: action)
            },
            reducer: { state, action in
                TimerExample.reduce(state: &state, action: action)
            },
            traceRecorder: recorder,
            logger: logger
        )
    }

    public var state: TimerExampleState {
        machine.state
    }

    public var durationSeconds: Int {
        duration
    }

    public func canSend(_ action: TimerExampleAction) -> Bool {
        machine.canSend(action)
    }

    @discardableResult
    public func send(_ action: TimerExampleAction) async -> TimerExampleState {
        let committedState = await machine.send(action)

        switch action {
        case .start, .resume:
            startTicker()
        case .pause, .reset:
            timerTask?.cancel()
            timerTask = nil
        case .tick:
            if case .completed = committedState {
                timerTask?.cancel()
                timerTask = nil
            }
        }

        return committedState
    }

    private func startTicker() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }

                guard let self else { return }
                let state = await self.send(.tick)
                if case .completed = state {
                    return
                }
            }
        }
    }
}

@MainActor
public struct TimerExampleView: View {
    @State private var model: TimerExampleScreenModel

    public init(model: TimerExampleScreenModel) {
        _model = State(initialValue: model)
    }

    public init(duration: Int = 25) {
        self.init(model: TimerExampleScreenModel(duration: duration))
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                stateContent
            }
            .padding()

            ObservationDebugOverlay(machine: model.machine)
                .padding()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .idle:
            Text("Timer ready")
            Button("Start") {
                Task { _ = await model.send(.start(duration: model.durationSeconds)) }
            }
            .disabled(!model.canSend(.start(duration: model.durationSeconds)))

        case .running(let remainingSeconds):
            Text("Running: \(remainingSeconds)s")
            Button("Pause") {
                Task { _ = await model.send(.pause) }
            }
            .disabled(!model.canSend(.pause))

        case .paused(let remainingSeconds):
            Text("Paused: \(remainingSeconds)s")
            Button("Resume") {
                Task { _ = await model.send(.resume) }
            }
            .disabled(!model.canSend(.resume))

        case .completed:
            Text("Completed")
            Button("Reset") {
                Task { _ = await model.send(.reset) }
            }
            .disabled(!model.canSend(.reset))
        }
    }
}
#endif
