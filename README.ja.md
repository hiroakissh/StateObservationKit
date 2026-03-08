# StateObservationKit

[English](README.md) | [Roadmap](ROADMAP.md) | [ロードマップ](ROADMAP.ja.md) | [Architecture](docs/architecture.md) | [アーキテクチャ](docs/architecture.ja.md)

StateObservationKit は、SwiftUI 向けの状態駆動アプリケーションアーキテクチャを構築するための軽量なステートマシンツールキットです。Swift Concurrency と SwiftUI Observation を組み合わせ、状態遷移を明示的にし、副作用を制御しやすくし、UI との接続を自然に保つことを目指しています。

## Vision

StateObservationKit は、アプリケーションの振る舞いを状態遷移で制御することを目的としています。

フラグ、コールバック、場当たり的な ViewModel にビジネスルールを分散させるのではなく、次のような単純なモデルで考えられるようにします。

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

現在の API では、アーキテクチャ上の `Intent` という考え方は `Action` として表現されています。
この文書では、設計概念としての説明には `Intent` を使い、コード例では current public API に合わせて `Action` / `ActionType` を使います。

## Core Philosophy

- State は single source of truth である
- 状態遷移は明示的で追跡可能であるべき
- StateMachine は Application layer に属し、UseCase を協調させる
- SwiftUI では Observation と `@Bindable` に自然に馴染むべき
- フルスタックなアーキテクチャフレームワークよりも軽量であるべき

## レイヤー上の位置づけ

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

StateObservationKit は Application layer に置くことを想定しています。フロー制御と状態変化を担い、副作用や外部依存は UseCase などの境界の向こう側に残します。

## このパッケージが提供するもの

| 種別 | 目的 | 主な利用シーン |
| --- | --- | --- |
| `TransitionDrivenStateMachine` | 型安全な `enum` で遷移と副作用を明示化する | アプリケーションフロー、業務ロジック制御、オーケストレーション |
| `ObservationDrivenStateMachine` | UI 層向けに状態をリアクティブに公開し、Reducer 実行を逐次化する | SwiftUI と Observation を使う状態管理、`canSend` と projection を伴う UI 制御 |
| `ObservationDrivenStateMachineMock` | 非同期処理を排除し、同期的で決定的な状態検証を可能にする | ユニットテスト、UI テスト、プレビュー |

## 用語対応

| アーキテクチャ上の概念 | 現在の API | 役割 |
| --- | --- | --- |
| State | `StateType` | 現在のアプリケーション状態を表す |
| Intent | `ActionType` | ユーザー入力やシステム入力を表す |
| Transition | `TransitionType` | 意味のある状態変化と必要なら副作用を定義する |
| Machine | `TransitionDrivenStateMachine` / `ObservationDrivenStateMachine` | 入力を解釈し、遷移を実行し、状態を公開する |

## 現在の位置づけと読み分け

StateObservationKit は現在、ロードマップとアーキテクチャ文書に沿う形へ再整理を進めています。そのため、一部の文書には目標状態の説明が含まれており、current implementation はまだ旧来の API 形状を含んでいます。

どの文書を優先して読むか迷う場合は、次の順で判断してください。

1. `ROADMAP.ja.md`: プロジェクトの進行方向と目標アーキテクチャ
2. `docs/architecture.ja.md`: 設計境界と依存方向
3. この README: current public API の契約
4. 型の doc comment と tests: current runtime behavior

ロードマップと current implementation に差異がある場合、その差分は「修正対象の migration gap」として扱います。単なる文書誤記として処理しないでください。

## 現在の Machine Contract

### `TransitionDrivenStateMachine`

- `dispatch(_:)` は状態変化を確定する唯一の公開入口です。
- 現在の `(state, action)` に一致する遷移がない場合は `TransitionDispatchError.invalidTransition` を投げ、状態は変わりません。
- 遷移の `effect` は `state` を確定する前に実行されます。
- `effect` が `CancellationError` 以外のエラーを投げた場合、状態は変わらず `TransitionDispatchError.effectFailed` を投げます。
- `effect` が follow-up の `Action` を返した場合、現在の遷移を確定してから、新しい状態に対して follow-up を dispatch します。

### `ObservationDrivenStateMachine`

- `dispatch(_:)` は即座に戻り、Reducer 実行を非同期にスケジュールします。
- `send(_:)` は同じ順序付きキューに入力を積み、結果の state が公開されるまで待機します。
- `canSend(_:)` は公開済み state と pending reducer の有無を見て、UI 向けの保守的な可用性判定を返します。
- Reducer 実行は内部の順序付きキューで逐次化されるため、`dispatch(_:)` と `send(_:)` は呼び出し順に適用されます。
- `state` は各 Reducer 実行が完了したあとに MainActor 上で更新されます。
- `dispatch(_:)` は fire-and-forget 用の API として残し、テストや orchestration で完了点が必要な場合は `send(_:)` を使います。

## 例: 明示的な遷移

```swift
enum PlayerState: StateType {
    case idle
    case playing
    case paused
}

enum PlayerAction: ActionType {
    case play
    case pause
}

enum PlayerTransition: TransitionType {
    typealias State = PlayerState
    typealias Action = PlayerAction

    case idlePlay
    case playingPause

    var from: PlayerState {
        switch self {
        case .idlePlay: return .idle
        case .playingPause: return .playing
        }
    }

    var action: PlayerAction {
        switch self {
        case .idlePlay: return .play
        case .playingPause: return .pause
        }
    }

    var to: PlayerState {
        switch self {
        case .idlePlay: return .playing
        case .playingPause: return .paused
        }
    }

    var effect: (@Sendable () async throws -> PlayerAction?)? { nil }
}

let machine = TransitionDrivenStateMachine<PlayerTransition>(initial: .idle)
try await machine.dispatch(.play)
print(await machine.state) // playing
```

状態変更の入口は `dispatch(_:)` のみです。Effect が follow-up の `Action` を返した場合は、現在の遷移が確定したあとに再 dispatch されます。

## 例: Observation に馴染む状態管理

```swift
let machine = ObservationDrivenStateMachine<PlayerState, PlayerAction>(
    initial: .idle,
    canSend: { state, action in
        switch (state, action) {
        case (.idle, .play), (.playing, .pause), (.paused, .play):
            return true
        default:
            return false
        }
    }
) { state, action in
    switch (state, action) {
    case (.idle, .play):
        state = .playing
    case (.idle, .pause):
        break
    case (.playing, .play):
        break
    case (.playing, .pause):
        state = .paused
    case (.paused, .play):
        state = .playing
    case (.paused, .pause):
        break
    }
}

let committedState = await machine.send(.play)
print(committedState) // playing
```

Observation 対応プラットフォームでは、SwiftUI から自然に利用できます。

```swift
struct PlayerView: View {
    @Bindable var machine: ObservationDrivenStateMachine<PlayerState, PlayerAction>

    var body: some View {
        let viewState = machine.project(PlayerControls.init)

        VStack {
            Text("\(String(describing: machine.state))")
            Button(viewState.primaryTitle) {
                Task {
                    _ = await machine.send(viewState.primaryAction)
                }
            }
                .disabled(!machine.canSend(viewState.primaryAction))
        }
    }
}

struct PlayerControls {
    let primaryTitle: String
    let primaryAction: PlayerAction

    init(state: PlayerState) {
        switch state {
        case .idle, .paused:
            self.primaryTitle = "Play"
            self.primaryAction = .play
        case .playing:
            self.primaryTitle = "Pause"
            self.primaryAction = .pause
        }
    }
}
```

入力値を Action に変換したい場合は、SwiftUI 利用時に `binding(_:send:)` が使えます。

```swift
TextField(
    "Title",
    text: machine.binding(\.draftTitle, send: EditorAction.titleChanged)
)
```

上のコードは最小例として View から Machine を直接扱っています。パッケージ同梱の sample では、SwiftUI からの入力はまず ScreenModel 風の `send(_:)` に集約し、その内部で必要なときだけ `dispatch(_:)` を呼ぶ形にしています。副作用、`Result` の処理、follow-up action を View に漏らしたくない場合はこの構成を推奨します。

## ドキュメント

- [Roadmap](ROADMAP.md)
- [ロードマップ](ROADMAP.ja.md)
- [Architecture](docs/architecture.md)
- [アーキテクチャ](docs/architecture.ja.md)
- [Q2 実行計画](docs/q2_execution_plan.ja.md)
- [English README](README.md)

## 2026 ロードマップ概要

| 四半期 | フォーカス |
| --- | --- |
| 2026 Q1 | コアアーキテクチャの安定化 |
| 2026 Q2 | Clean Architecture 統合 |
| 2026 Q3 | SwiftUI エルゴノミクスとツール整備 |
| 2026 Q4 | 本番運用とエコシステム整備 |

詳細は [ROADMAP.ja.md](ROADMAP.ja.md) を参照してください。

## テスト

```bash
swift test
swift build -Xswiftc -strict-concurrency=complete
```

Observation と SwiftUI が利用できる環境では、UI 連携サンプルもパッケージビルドの一部として検証されます。

## 対応プラットフォーム

- iOS 17 以降
- macOS 14 以降

## ライセンス

[LICENSE](LICENSE) を参照してください。
