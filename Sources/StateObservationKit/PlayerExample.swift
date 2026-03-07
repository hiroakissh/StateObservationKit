import Foundation

public protocol AudioServiceProtocol: Sendable {
    func play() async throws
    func pause() async throws
    func resume() async throws
    func stop() async throws
}

public protocol PlayerUseCaseProtocol: Sendable {
    func play() async throws
    func pause() async throws
    func resume() async throws
    func stop() async throws
}

public struct PlayerEnvironment: Sendable {
    public let playerUseCase: any PlayerUseCaseProtocol

    public init(playerUseCase: any PlayerUseCaseProtocol) {
        self.playerUseCase = playerUseCase
    }

    public static let live = Self(
        playerUseCase: PlayerUseCase(audioService: AudioService.shared)
    )
}

public actor PlayerUseCase: PlayerUseCaseProtocol {
    private let audioService: any AudioServiceProtocol

    public init(audioService: any AudioServiceProtocol) {
        self.audioService = audioService
    }

    public func play() async throws {
        try await audioService.play()
    }

    public func pause() async throws {
        try await audioService.pause()
    }

    public func resume() async throws {
        try await audioService.resume()
    }

    public func stop() async throws {
        try await audioService.stop()
    }
}

private enum PlayerExampleEnvironmentScope {
    @TaskLocal static var current: PlayerEnvironment?
}

private actor PlayerEnvironmentStore {
    static let shared = PlayerEnvironmentStore(environment: .live)

    private var environment: PlayerEnvironment

    init(environment: PlayerEnvironment) {
        self.environment = environment
    }

    func current() -> PlayerEnvironment {
        environment
    }

    func replace(with environment: PlayerEnvironment) -> PlayerEnvironment {
        let previous = self.environment
        self.environment = environment
        return previous
    }

    func reset() {
        environment = .live
    }
}

public func configurePlayerExampleEnvironment(_ environment: PlayerEnvironment) async {
    _ = await PlayerEnvironmentStore.shared.replace(with: environment)
}

public func resetPlayerExampleEnvironment() async {
    await PlayerEnvironmentStore.shared.reset()
}

public func withPlayerExampleEnvironment<T: Sendable>(
    _ environment: PlayerEnvironment,
    operation: @Sendable () async throws -> T
) async rethrows -> T {
    try await PlayerExampleEnvironmentScope.$current.withValue(environment) {
        try await operation()
    }
}

private func currentPlayerExampleEnvironment() async -> PlayerEnvironment {
    if let environment = PlayerExampleEnvironmentScope.current {
        return environment
    }

    return await PlayerEnvironmentStore.shared.current()
}

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
                let environment = await currentPlayerExampleEnvironment()
                try await environment.playerUseCase.play()
                return nil
            }
        case .playing_pause:
            {
                let environment = await currentPlayerExampleEnvironment()
                try await environment.playerUseCase.pause()
                return nil
            }
        case .paused_resume:
            {
                let environment = await currentPlayerExampleEnvironment()
                try await environment.playerUseCase.resume()
                return nil
            }
        case .playing_stop, .paused_stop:
            {
                let environment = await currentPlayerExampleEnvironment()
                try await environment.playerUseCase.stop()
                return nil
            }
        }
    }
}

// MARK: - Sample Async Mock Service

public actor AudioService: AudioServiceProtocol {
    public static let shared = AudioService()
    public func play() async throws { print("▶️ Playing...") }
    public func pause() async throws { print("⏸ Paused.") }
    public func resume() async throws { print("▶️ Resumed.") }
    public func stop() async throws { print("🛑 Stopped.") }
}
