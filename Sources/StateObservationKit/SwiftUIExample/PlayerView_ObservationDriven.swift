#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

@Observable
@MainActor
final class PlayerScreenModel {
    @ObservationIgnored
    private let machine: ObservationDrivenStateMachine<PlayerState, PlayerAction>
    @ObservationIgnored
    private let playerUseCase: any PlayerUseCaseProtocol
    var errorMessage: String?

    init(environment: PlayerEnvironment = .live) {
        self.playerUseCase = environment.playerUseCase
        self.machine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
            initial: .idle
        ) { state, action in
            Self.reduce(state: &state, action: action)
        }
    }

    var state: PlayerState {
        machine.state
    }

    var stateLabel: String {
        switch state {
        case .idle: "Idle"
        case .playing: "Playing"
        case .paused: "Paused"
        case .stopped: "Stopped"
        }
    }

    // UI input enters through `send(_:)`; this method decides whether the action is valid,
    // forwards accepted input to the machine, and then handles side-effect results.
    func send(_ action: PlayerAction) {
        guard let operation = Self.operation(
            for: state,
            action: action,
            playerUseCase: playerUseCase
        ) else {
            return
        }

        errorMessage = nil
        // `dispatch(_:)` remains the lower-level primitive that actually commits machine state.
        machine.dispatch(action)

        Task {
            let result = await operation()
            await MainActor.run {
                self.consume(result)
            }
        }
    }

    nonisolated private static func reduce(state: inout PlayerState, action: PlayerAction) {
        switch state {
        case .idle:
            switch action {
            case .play:
                state = .playing
            case .pause, .resume, .stop:
                break
            }
        case .playing:
            switch action {
            case .pause:
                state = .paused
            case .stop:
                state = .stopped
            case .play, .resume:
                break
            }
        case .paused:
            switch action {
            case .resume:
                state = .playing
            case .stop:
                state = .stopped
            case .play, .pause:
                break
            }
        case .stopped:
            switch action {
            case .play:
                state = .playing
            case .pause, .resume, .stop:
                break
            }
        }
    }

    nonisolated private static func operation(
        for state: PlayerState,
        action: PlayerAction,
        playerUseCase: any PlayerUseCaseProtocol
    ) -> (@Sendable () async -> Result<Void, Error>)? {
        switch state {
        case .idle:
            switch action {
            case .play:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.play()
                    }
                }
            case .pause, .resume, .stop:
                return nil
            }
        case .playing:
            switch action {
            case .pause:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.pause()
                    }
                }
            case .stop:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.stop()
                    }
                }
            case .play, .resume:
                return nil
            }
        case .paused:
            switch action {
            case .resume:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.resume()
                    }
                }
            case .stop:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.stop()
                    }
                }
            case .play, .pause:
                return nil
            }
        case .stopped:
            switch action {
            case .play:
                return {
                    await Result<Void, Error>.catching {
                        try await playerUseCase.play()
                    }
                }
            case .pause, .resume, .stop:
                return nil
            }
        }
    }

    private func consume(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
struct PlayerView_ObservationDriven: View {
    @State private var model: PlayerScreenModel

    init(environment: PlayerEnvironment = .live) {
        _model = State(initialValue: PlayerScreenModel(environment: environment))
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 20) {
            Text("🎧 State: \(model.stateLabel)")
                .font(.headline)

            if let errorMessage = model.errorMessage {
                Text("⚠️ \(errorMessage)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            // The View only sends user intent to the ScreenModel.
            switch model.state {
            case .idle:
                Button("▶️ Play") { model.send(.play) }
            case .playing:
                Button("⏸ Pause") { model.send(.pause) }
                Button("🛑 Stop") { model.send(.stop) }
            case .paused:
                Button("▶️ Resume") { model.send(.resume) }
                Button("🛑 Stop") { model.send(.stop) }
            case .stopped:
                Button("▶️ Play Again") { model.send(.play) }
            }
        }
        .padding()
        .animation(.easeInOut, value: model.state)
    }
}
#endif
