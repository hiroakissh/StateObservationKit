# TransitionDrivenStateMachine 指示書

## 概要
StateObservationKit に、`State × Action × Effect` の関係を明示的に型で表現するドメイン特化の遷移駆動ステートマシン層を追加します。全ての遷移を列挙した `enum` を中心に据え、Swift Concurrency と親和性の高い宣言的フレームワークを目指します。

## ディレクトリ構成
```
StateObservationKit/
 ├─ Sources/
 │   └─ StateObservationKit/
 │       ├─ TransitionDrivenStateMachine.swift
 │       ├─ PlayerExample.swift
 │       └─ Core/
 │           ├─ StateType.swift
 │           ├─ ActionType.swift
 │           └─ TransitionType.swift
 └─ Tests/
     └─ StateObservationKitTests/
         └─ TransitionDrivenStateMachineTests.swift
```

## ゴール
- 遷移は動的組み合わせではなく `enum` ケースとして列挙する。
- 各遷移に `from` / `to` / `action` / `effect` を束ね、責務を一元化する。
- 状態遷移は `dispatch(_:)` のみから行い、副作用と状態変更を統制する。
- Effect は async/await に対応し、結果で状態を更新できる。
- `Transition` enum を読むだけでアプリ全体の遷移構造を把握できるようにする。

## 実装要件
### 1. コアプロトコル（`Sources/StateObservationKit/Core/`）
```swift
public protocol StateType: Equatable, Sendable {}
public protocol ActionType: Equatable, Sendable {}

public protocol TransitionType: Equatable, Sendable, CaseIterable {
    associatedtype State: StateType
    associatedtype Action: ActionType

    var from: State { get }
    var action: Action { get }
    var to: State { get }
    var effect: (suspend () async throws -> Void)? { get }
}
```

### 2. TransitionDrivenStateMachine（`Sources/StateObservationKit/TransitionDrivenStateMachine.swift`）
```swift
import Foundation

public actor TransitionDrivenStateMachine<T: TransitionType>: Sendable {
    private(set) var state: T.State
    private let hook: ((T.State) -> Void)?

    public init(initial: T.State, hook: ((T.State) -> Void)? = nil) {
        self.state = initial
        self.hook = hook
        hook?(initial)
    }

    public func dispatch(_ action: T.Action) async {
        guard let transition = matchTransition(for: action) else {
            print("⚠️ Invalid transition: \(state) × \(action)")
            return
        }

        if let effect = transition.effect {
            do { try await effect() }
            catch { print("⚠️ Effect failed:", error) }
        }

        state = transition.to
        hook?(state)
    }

    private func matchTransition(for action: T.Action) -> T? {
        T.allCases.first(where: { $0.from == state && $0.action == action })
    }
}
```

### 3. Player ドメイン例（`Sources/StateObservationKit/PlayerExample.swift`）
```swift
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

    public var effect: (suspend () async throws -> Void)? {
        switch self {
        case .idle_play:
            { try await AudioService.shared.play() }
        case .playing_pause:
            { try await AudioService.shared.pause() }
        case .paused_resume:
            { try await AudioService.shared.resume() }
        case .playing_stop, .paused_stop:
            { try await AudioService.shared.stop() }
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
```

### 4. テスト（`Tests/StateObservationKitTests/TransitionDrivenStateMachineTests.swift`）
```swift
import XCTest
@testable import StateObservationKit

final class TransitionDrivenStateMachineTests: XCTestCase {
    func testPlayerTransitions() async throws {
        let machine = TransitionDrivenStateMachine<PlayerTransition>(
            initial: .idle,
            hook: { print("🎯 State →", $0) }
        )

        await machine.dispatch(.play)
        await machine.dispatch(.pause)
        await machine.dispatch(.resume)
        await machine.dispatch(.stop)
    }
}
```
想定ログ:
```
🎯 State → idle
▶️ Playing...
⏸ Paused.
▶️ Resumed.
🛑 Stopped.
```

## 開発ガイドライン
| 項目 | 内容 |
| --- | --- |
| 状態とアクションを動的に組み合わせない | すべての遷移を enum で明示し、型で保証する。 |
| 副作用は Transition 単位で持たせる | どの遷移で何が起こるかを1箇所に集約する。 |
| `dispatch(_:)` が唯一のエントリポイント | 副作用と状態遷移を意図的に統制する。 |
| Hook は軽量に保つ | View 通知やログ用途に限定し、重処理は Effect に任せる。 |
| Observation 統合は後続拡張 | SwiftUI バインディングは次フェーズで提供。 |

## Package.swift 追記例
```swift
.products: [
    .library(
        name: "StateObservationKit",
        targets: ["StateObservationKit"]
    ),
],
.targets: [
    .target(name: "StateObservationKit", path: "Sources"),
    .testTarget(
        name: "StateObservationKitTests",
        dependencies: ["StateObservationKit"],
        path: "Tests"
    )
]
```

## 検証チェックリスト
- TransitionType enum が有効な state/action の組み合わせをすべて網羅している。
- 状態遷移は `dispatch(_:)` を通じてのみ発生する。
- Effect クロージャが async/await で動作し、throws できる。
- Hook が新しい状態に入るたびに発火する。
- PlayerExample が期待ログを出力する。

## リリースとメタデータ
- リポジトリ例: `yourname/StateObservationKit`
- 推奨タグ: `v1.2.0`
- モジュールコード名: `TransitionDrivenStateMachine`

## 開発者メモ
- 遷移を第一級の型として扱い、ドメイン DSL を明示的に保つ。
- 状態・アクション・副作用の責務境界を明確にする。
- 新規参入者が `Transition` enum を読むだけでフローを理解できるようにする。
- 今後の予定: Observation 対応版（`@ObservableStateMachine`）と Middleware 追加。

## 納品形態
この指示書（`instruction/1_TransitionDrivenStateMachine_Instruction.md`）を自動生成エージェントに渡すだけで、コアプロトコル、アクター、サンプルドメイン、テスト、副作用、拡張ポイントを含むモジュール一式を構築できます。
