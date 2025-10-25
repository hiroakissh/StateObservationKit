# StateObservationKit

TransitionDrivenStateMachine は、`State × Action × Effect` を型レベルで宣言できる Swift Concurrency 対応の状態管理モジュールです。各遷移を `enum` で表現し、副作用を遷移単位にひもづけることで、アプリ全体のフローをひと目で理解できます。

## 特徴
- **Transition enum**: すべての状態遷移を1つの `enum` で列挙。
- **型安全な副作用**: 遷移と副作用をセットで宣言し、async/await で実行。
- **Hook**: 状態遷移ごとに軽量な通知フックを発火。
- **サンプル実装**: `PlayerTransition` が状態・アクション・副作用の結び付けを示します。

## ディレクトリ
```
Sources/
 └─ StateObservationKit/
     ├─ Core/                // StateType / ActionType / TransitionType
     ├─ TransitionDrivenStateMachine.swift
     └─ PlayerExample.swift
Tests/
 └─ StateObservationKitTests/
     └─ TransitionDrivenStateMachineTests.swift
```

## 使い方
```swift
let machine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { print("🎯", $0) }
)
await machine.dispatch(.play)
```
`PlayerTransition` の各ケースに `from` / `action` / `to` / `effect` を実装することで、状態と副作用を1箇所で管理できます。

## テスト
サンドボックスの制限がない環境で以下を実行してください。
```
swift test
```
想定ログ:
```
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
