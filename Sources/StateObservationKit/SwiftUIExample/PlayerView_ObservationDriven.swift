#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

@MainActor
struct PlayerView_ObservationDriven: View {
    @State private var machine: ObservationDrivenStateMachine<PlayerState, PlayerAction>

    init() {
        _machine = State(
            initialValue: ObservationDrivenStateMachine<PlayerState, PlayerAction>(
                initial: .idle,
                canSend: { state, action in
                    PlayerViewProjection.isActionAvailable(state: state, action: action)
                }
            ) { state, action in
                switch (state, action) {
                case (.idle, .play):
                    try? await AudioService.shared.play()
                    state = .playing
                case (.playing, .pause):
                    try? await AudioService.shared.pause()
                    state = .paused
                case (.paused, .resume):
                    try? await AudioService.shared.resume()
                    state = .playing
                case (.playing, .stop), (.paused, .stop):
                    try? await AudioService.shared.stop()
                    state = .stopped
                default:
                    break
                }
            }
        )
    }

    var body: some View {
        @Bindable var machine = machine
        let viewState = machine.project(PlayerViewProjection.init)

        VStack(spacing: 20) {
            Text(viewState.title)
                .font(.headline)

            Button(viewState.primaryControl.title) {
                machine.send(viewState.primaryControl.action)
            }
            .disabled(!machine.canSend(viewState.primaryControl.action))

            if let secondaryControl = viewState.secondaryControl {
                Button(secondaryControl.title) {
                    machine.send(secondaryControl.action)
                }
                .disabled(!machine.canSend(secondaryControl.action))
            }
        }
        .padding()
        .animation(.easeInOut, value: machine.state)
    }
}

private struct PlayerViewProjection {
    struct Control {
        let title: String
        let action: PlayerAction
    }

    let title: String
    let primaryControl: Control
    let secondaryControl: Control?

    init(state: PlayerState) {
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
            self.primaryControl = Control(title: "🔁 Reset", action: .play)
            self.secondaryControl = nil
        }
    }

    static func isActionAvailable(state: PlayerState, action: PlayerAction) -> Bool {
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
}
#endif
