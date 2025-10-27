# StateObservationKit

StateObservationKit は、Swift Concurrency と SwiftUI Observation を軸にしたステートマシンコレクションです。遷移を厳密に管理して副作用を型安全に扱う `TransitionDrivenStateMachine` と、UI 層での双方向バインディングに最適化された `ObservationDrivenStateMachine`、そしてテスト容易性を高めるモック群を収録しています。用途や開発段階に応じて最適なモデルを選択し、同一ドメインモデルを共有しながら柔軟に切り替えられます。

## 提供するステートマシン

| 種別 | 目的 | 主な利用シーン |
|------|------|----------------|
| `TransitionDrivenStateMachine` | 遷移と副作用を `enum` で明示的に管理。Actor による排他制御でビジネスロジックを安全に実行。 | ドメイン層 / UseCase 層 |
| `ObservationDrivenStateMachine` | Reducer と Observation を利用して状態をリアクティブに公開。UI とリアルタイム同期。 | ViewModel 層 / SwiftUI |
| `ObservationDrivenStateMachineMock` | Reducer を差し替えて状態変化とアクション履歴を同期検証できるテストダブル。 | UI テスト / スナップショットテスト |

## 機能ハイライト

- **状態遷移の見える化**: 遷移を 1 つの `enum` に集約し、`from`・`to` と副作用を合わせて定義できます。
- **Observation との親和性**: `@Observable` を条件付きで適用し、対応環境では SwiftUI の `@Bindable` とシームレスに連携します。
- **逐次実行される Reducer**: `ObservationDrivenStateMachine` は内部アクターでアクションを直列処理し、期待どおりの順序で状態を書き戻します。
- **テスト容易性**: 共通プロトコル `ObservationStateMachineType` とモック実装により、副作用を伴う処理を切り離してユニットテストが行えます。
- **実装サンプル**: Player ドメインを用いた SwiftUI 例で、実際の UI 連携と非同期副作用の扱い方を学べます。

## TransitionDrivenStateMachine の使い方

ビジネスロジックを厳密に制御したい場合は、遷移ごとに副作用を定義できる `TransitionDrivenStateMachine` を使用します。

```swift
enum PlayerTransition: TransitionType {
    case play
    case pause

    var from: PlayerState {
        switch self {
        case .play: return .idle
        case .pause: return .playing
        }
    }

    var to: PlayerState {
        switch self {
        case .play: return .playing
        case .pause: return .paused
        }
    }

    func effect() async throws {
        switch self {
        case .play: try await AudioService.shared.play()
        case .pause: try await AudioService.shared.pause()
        }
    }
}

let transitionMachine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { transition in
        print("🚦", transition)
    }
)

await transitionMachine.dispatch(.play)
```

状態と副作用を 1 つの型に集約できるため、ドメイン層でのユースケース実装や監査ログの取得が簡単に行えます。

## ObservationDrivenStateMachine の使い方

UI 層で状態バインディングを簡潔に扱いたい場合は `ObservationDrivenStateMachine` を利用します。Reducer を渡すだけで非同期アクションを逐次処理し、`@Observable` によって状態変更が自動通知されます。

```swift
let observationMachine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
    initial: .idle
) { state, action in
    switch (state, action) {
    case (.idle, .play):
        try? await AudioService.shared.play()
        state = .playing
    case (.playing, .pause):
        try? await AudioService.shared.pause()
        state = .paused
    default:
        break
    }
}

observationMachine.dispatch(.play)
```

### SwiftUI と組み合わせる

`PlayerView_ObservationDriven` では、`@Bindable` でステートマシンを監視しつつ UI を構築しています。

```swift
struct PlayerView_ObservationDriven: View {
    @Bindable var machine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
        initial: .idle
    ) { state, action in
        switch (state, action) {
        case (.idle, .play):
            try? await AudioService.shared.play()
            state = .playing
        case (.playing, .stop):
            try? await AudioService.shared.stop()
            state = .stopped
        default:
            break
        }
    }

    var body: some View {
        VStack {
            Text(machine.stateLabel)
            Button("▶️ Play") { machine.dispatch(.play) }
        }
    }
}
```

Reducer にはメソッド参照やクロージャを渡せるため、View 側では最小限の記述で済みます。状態の変更順序は内部アクターによって保証されるため、複数の `dispatch` を連続で呼んでも状態の破壊的な巻き戻りが起きません。

## モックとテスト戦略

Observation 系の依存を排除したい場合は `ObservationDrivenStateMachineMock` を利用してください。`ObservationStateMachineType` に準拠しているため、プロダクションコードではプロトコルを依存注入し、テストではモックに差し替えるだけでアクション履歴と状態推移を検証できます。

```swift
let mockMachine = ObservationDrivenStateMachineMock<PlayerState, PlayerAction>(initial: .idle) { state, action in
    if action == .play { state = .playing }
}

mockMachine.dispatch(.play)

XCTAssertEqual(mockMachine.state, .playing)
XCTAssertEqual(mockMachine.receivedActions, [.play])
```

テストコードの具体例は `ObservationDrivenStateMachineTests` を参照してください。実機テストや UI テストでは、非同期副作用を排除した Reducer を渡すことで、View ロジックを純粋な状態遷移として検証できます。

## ディレクトリ構成

```text
Sources/
 └─ StateObservationKit/
    ├─ Core/
    │   ├─ StateType.swift / ActionType.swift / TransitionType.swift
    │   └─ ObservationStateMachineType.swift
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

## テスト実行手順

1. 依存関係を解決できる環境で次のコマンドを実行します。
   ```bash
   swift test
   ```
2. Observation が利用できるプラットフォームでは、SwiftUI 連携サンプルのビルドも同時に検証されます。
3. ログ例:
   ```text
   🎯 State → idle
   ▶️ Playing...
   ⏸ Paused.
   ▶️ Resumed.
   🛑 Stopped.
   ```

## リリース手順

1. すべてのテストが成功していることを確認します。
2. バージョンを更新する場合は `git tag 0.1.0` のようにタグを作成します。
3. リモートへ公開する場合は `git push origin main --tags` を実行してください。

## ライセンス

組織またはプロジェクトのポリシーに従って追記してください。
