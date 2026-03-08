#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

@Observable
@MainActor
final class PlayerScreenModel {
    @ObservationIgnored
    private let stateProvider: @MainActor () -> PlayerState
    @ObservationIgnored
    private let canSendAction: @MainActor (PlayerAction) -> Bool
    @ObservationIgnored
    private let dispatchAction: @MainActor (PlayerAction) -> Void
    @ObservationIgnored
    private let playerUseCase: any PlayerUseCaseProtocol
    var errorMessage: String?

    init<Machine: ObservationStateMachineType>(
        machine: Machine,
        playerUseCase: any PlayerUseCaseProtocol
    ) where Machine.State == PlayerState, Machine.Action == PlayerAction {
        self.stateProvider = { machine.state }
        self.canSendAction = { action in
            machine.canSend(action)
        }
        self.dispatchAction = { action in
            machine.dispatch(action)
        }
        self.playerUseCase = playerUseCase
    }

    convenience init(environment: PlayerEnvironment = .live) {
        self.init(
            machine: Self.makeMachine(),
            playerUseCase: environment.playerUseCase
        )
    }

    private static func makeMachine() -> ObservationDrivenStateMachine<PlayerState, PlayerAction> {
        ObservationDrivenStateMachine<PlayerState, PlayerAction>(
            initial: .idle,
            canSend: { state, action in
                Self.isActionAvailable(state: state, action: action)
            }
        ) { state, action in
            Self.reduce(state: &state, action: action)
        }
    }

    var state: PlayerState {
        stateProvider()
    }

    var viewState: PlayerViewProjection {
        PlayerViewProjection(state: state, errorMessage: errorMessage)
    }

    func canSend(_ action: PlayerAction) -> Bool {
        canSendAction(action)
    }

    // UI input enters through `send(_:)`; this method decides whether the action is valid,
    // forwards accepted input to the machine, and then handles side-effect results.
    func send(_ action: PlayerAction) {
        guard canSend(action),
              let operation = Self.operation(
                  for: state,
                  action: action,
                  playerUseCase: playerUseCase
              ) else {
            return
        }

        errorMessage = nil
        // `dispatch(_:)` remains the lower-level primitive that actually commits machine state.
        dispatchAction(action)

        Task {
            let result = await operation()
            await MainActor.run {
                self.consume(result)
            }
        }
    }

    nonisolated private static func isActionAvailable(
        state: PlayerState,
        action: PlayerAction
    ) -> Bool {
        switch (state, action) {
        case (.idle, .play),
             (.playing, .pause),
             (.playing, .stop),
             (.paused, .resume),
             (.paused, .stop),
             (.stopped, .play):
            return true
        default:
            return false
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

struct PlayerViewProjection {
    struct Control {
        let title: String
        let action: PlayerAction
    }

    let title: String
    let errorMessage: String?
    let primaryControl: Control
    let secondaryControl: Control?

    init(state: PlayerState, errorMessage: String?) {
        self.errorMessage = errorMessage

        switch state {
        case .idle:
            self.title = "🎧 State: Idle"
            self.primaryControl = Control(title: "▶️ Play", action: .play)
            self.secondaryControl = nil
        case .playing:
            self.title = "🎧 State: Playing"
            self.primaryControl = Control(title: "⏸ Pause", action: .pause)
            self.secondaryControl = Control(title: "🛑 Stop", action: .stop)
        case .paused:
            self.title = "🎧 State: Paused"
            self.primaryControl = Control(title: "▶️ Resume", action: .resume)
            self.secondaryControl = Control(title: "🛑 Stop", action: .stop)
        case .stopped:
            self.title = "🎧 State: Stopped"
            self.primaryControl = Control(title: "▶️ Play Again", action: .play)
            self.secondaryControl = nil
        }
    }
}

@MainActor
struct PlayerView_ObservationDriven: View {
    @State private var model: PlayerScreenModel

    init(model: PlayerScreenModel) {
        _model = State(initialValue: model)
    }

    init(environment: PlayerEnvironment = .live) {
        self.init(model: PlayerScreenModel(environment: environment))
    }

    var body: some View {
        @Bindable var model = model
        let viewState = model.viewState

        VStack(spacing: 20) {
            Text(viewState.title)
                .font(.headline)

            if let errorMessage = viewState.errorMessage {
                Text("⚠️ \(errorMessage)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(viewState.primaryControl.title) {
                model.send(viewState.primaryControl.action)
            }
            .disabled(!model.canSend(viewState.primaryControl.action))

            if let secondaryControl = viewState.secondaryControl {
                Button(secondaryControl.title) {
                    model.send(secondaryControl.action)
                }
                .disabled(!model.canSend(secondaryControl.action))
            }
        }
        .padding()
        .animation(.easeInOut, value: model.state)
    }
}
#endif
