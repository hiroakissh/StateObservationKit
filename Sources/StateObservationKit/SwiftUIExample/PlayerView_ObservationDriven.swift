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

    func send(_ action: PlayerAction) {
        guard let operation = Self.operation(
            for: state,
            action: action,
            playerUseCase: playerUseCase
        ) else {
            return
        }

        machine.dispatch(action)

        Task {
            try? await operation()
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
    ) -> (@Sendable () async throws -> Void)? {
        switch state {
        case .idle:
            switch action {
            case .play:
                return { try await playerUseCase.play() }
            case .pause, .resume, .stop:
                return nil
            }
        case .playing:
            switch action {
            case .pause:
                return { try await playerUseCase.pause() }
            case .stop:
                return { try await playerUseCase.stop() }
            case .play, .resume:
                return nil
            }
        case .paused:
            switch action {
            case .resume:
                return { try await playerUseCase.resume() }
            case .stop:
                return { try await playerUseCase.stop() }
            case .play, .pause:
                return nil
            }
        case .stopped:
            switch action {
            case .play:
                return { try await playerUseCase.play() }
            case .pause, .resume, .stop:
                return nil
            }
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
