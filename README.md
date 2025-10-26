# StateObservationKit

StateObservationKit は、Swift Concurrency と SwiftUI Observation を活用した 2 系統のステートマシンを提供します。明示的な遷移定義でビジネスロジックを厳密に制御する `TransitionDrivenStateMachine` と、Observation フレームワークに乗せたリアクティブな `ObservationDrivenStateMachine` を用途に応じて選べます。

## 特徴
- **Transition enum**: すべての状態遷移を 1 つの `enum` で列挙し、副作用を型安全にひも付け。
- **Observation 連携**: SwiftUI 向けの軽量 Reducer 形式で状態更新を自動バインディング。
- **Hook / Effect**: 遷移毎の副作用やフックでロジックの見通しを確保。
- **サンプル実装**: Player ドメインを使った遷移駆動 / 観測駆動の両方のサンプルを収録。
- **モック対応**: プロトコルとテスト用モックを同梱し、副作用に依存しないユニットテストを書けます。

## Choose Your Style

| Type | Description | Use case |
|------|-------------|-----------|
| `TransitionDrivenStateMachine` | 明示的遷移と副作用を enum で管理。Actor 隔離で堅牢。 | ビジネスロジック / UseCase 層 |
| `ObservationDrivenStateMachine` | SwiftUI フレンドリーな Reducer 形式。Observation で自動通知。 | UI / ViewModel 層 |
| `ObservationDrivenStateMachineMock` | Reducer をすり替えて状態遷移を同期確認できるテストダブル。 | UI / ViewModel のユニットテスト |

### Example

```swift
// Transition-driven (strict)
let transitionMachine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { print("🎯", $0) }
)
await transitionMachine.dispatch(.play)

// Observation-driven (reducer-based)
let observationMachine = ObservationDrivenStateMachine(initial: PlayerState.idle) { state, action in
    switch (state, action) {
    case (.idle, .play):
        try? await AudioService.shared.play()
        state = .playing
    default:
        break
    }
}
observationMachine.dispatch(.play)

// Mock (replace reducer and assert synchronously)
let mockMachine = ObservationDrivenStateMachineMock(initial: PlayerState.idle) { state, action in
    if action == .play { state = .playing }
}
mockMachine.dispatch(.play)
XCTAssertEqual(mockMachine.state, .playing)
```

## ディレクトリ
```text
Sources/
 └─ StateObservationKit/
    ├─ Core/                // StateType / ActionType / TransitionType / ObservationStateMachineType
    ├─ TransitionDrivenStateMachine.swift
    ├─ ObservationDrivenStateMachine.swift
    ├─ Testing/
    │   └─ ObservationDrivenStateMachineMock.swift
    ├─ PlayerExample.swift
    └─ SwiftUIExample/
         └─ PlayerView_ObservationDriven.swift
Tests/
 └─ StateObservationKitTests/
     ├─ TransitionDrivenStateMachineTests.swift
     └─ ObservationDrivenStateMachineTests.swift
```

## 使い方
```swift
let machine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { print("🎯", $0) }
)
await machine.dispatch(.play)
```
`PlayerTransition` の各ケースに `from` / `action` / `to` / `effect` を実装することで、状態と副作用を 1 箇所で管理できます。

Observation 駆動のサンプルは `PlayerView_ObservationDriven` を参照してください。`@Bindable` でバインドした `ObservationDrivenStateMachine` が SwiftUI とリアルタイムに同期します。

## テスト
サンドボックスの制限がない環境で以下を実行してください。
```bash
swift test
```
想定ログ:
```text
🎯 State → idle
▶️ Playing...
⏸ Paused.
▶️ Resumed.
🛑 Stopped.
```

## リリース
1. コード確認後に `git tag 0.1.0` を作成します。
2. GitHub などに push する際は `git push origin main --tags` を実行してください。

## ライセンス
プロジェクトポリシーに合わせて追加してください。
