#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

struct PlayerView_ObservationDriven: View {
    @Bindable var machine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
        initial: .idle
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

    var body: some View {
        VStack(spacing: 20) {
            Text("🎧 State: \(machine.stateLabel)")
                .font(.headline)

            switch machine.state {
            case .idle:
                Button("▶️ Play") { machine.dispatch(.play) }
            case .playing:
                Button("⏸ Pause") { machine.dispatch(.pause) }
                Button("🛑 Stop") { machine.dispatch(.stop) }
            case .paused:
                Button("▶️ Resume") { machine.dispatch(.resume) }
                Button("🛑 Stop") { machine.dispatch(.stop) }
            case .stopped:
                Button("🔁 Reset") { machine.dispatch(.play) }
            }
        }
        .padding()
        .animation(.easeInOut, value: machine.state)
    }
}

private extension ObservationDrivenStateMachine where State == PlayerState, Action == PlayerAction {
    var stateLabel: String {
        switch state {
        case .idle: "Idle"
        case .playing: "Playing"
        case .paused: "Paused"
        case .stopped: "Stopped"
        }
    }
}
#endif
