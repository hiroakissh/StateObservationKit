import Foundation

// MARK: - Domain States

public enum PlayerState: StateType {
    case idle
    case playing
    case paused
    case stopped
}

// MARK: - Domain Actions

public enum PlayerAction: ActionType {
    case play
    case pause
    case resume
    case stop
}

// MARK: - Transition Enum

public enum PlayerTransition: TransitionType {
    public typealias State = PlayerState
    public typealias Action = PlayerAction

    case idle_play
    case playing_pause
    case paused_resume
    case playing_stop
    case paused_stop

    public var from: State {
        switch self {
        case .idle_play: .idle
        case .playing_pause: .playing
        case .paused_resume: .paused
        case .playing_stop: .playing
        case .paused_stop: .paused
        }
    }

    public var action: Action {
        switch self {
        case .idle_play: .play
        case .playing_pause: .pause
        case .paused_resume: .resume
        case .playing_stop, .paused_stop: .stop
        }
    }

    public var to: State {
        switch self {
        case .idle_play, .paused_resume: .playing
        case .playing_pause: .paused
        case .playing_stop, .paused_stop: .stopped
        }
    }

    public var effect: (@Sendable () async throws -> Action?)? {
        switch self {
        case .idle_play:
            {
                try await AudioService.shared.play()
                return nil
            }
        case .playing_pause:
            {
                try await AudioService.shared.pause()
                return nil
            }
        case .paused_resume:
            {
                try await AudioService.shared.resume()
                return nil
            }
        case .playing_stop, .paused_stop:
            {
                try await AudioService.shared.stop()
                return nil
            }
        }
    }
}

// MARK: - Sample Async Mock Service

public final actor AudioService {
    public static let shared = AudioService()
    public func play() async throws { print("▶️ Playing...") }
    public func pause() async throws { print("⏸ Paused.") }
    public func resume() async throws { print("▶️ Resumed.") }
    public func stop() async throws { print("🛑 Stopped.") }
}
