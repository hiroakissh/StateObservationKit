# StateObservationKit

[English](README.md) | [Roadmap](ROADMAP.md) | [ロードマップ](ROADMAP.ja.md) | [Architecture](docs/architecture.md) | [アーキテクチャ](docs/architecture.ja.md)

StateObservationKit は、SwiftUI 向けの軽量なアーキテクチャ基盤です。大きな ViewModel や重いフレームワークに寄せるのではなく、**状態遷移を中心に設計したアーキテクチャを、そのままコードとして実行可能にする**ことを目指しています。

設計した構造を、実装でも同じ構造として保つ。
それが StateObservationKit の出発点です。

## README の読み順（思想 → 図 → 具体例 → 導入理由）

この README は、次の順番で理解できるように構成しています。

1. 思想（なぜ必要か）
2. 図（どう分離するか）
3. 具体例（どう書くか）
4. 導入理由（どんなチームに合うか）

## The Problem（解決したい課題）

SwiftUI プロジェクトでは、時間とともにアーキテクチャが崩れやすくなります。

| アプローチ | よくある課題 |
| --- | --- |
| MVVM | ViewModel に責務が集中し、状態と業務ルールが肥大化しやすい |
| Redux 系 | スケールとともにボイラープレートが増えやすい |
| 包括的フレームワーク | 強力だが、小〜中規模では導入・維持コストが重くなりやすい |

結果として、設計は図に残り、実装は別の形へ崩れていく。
StateObservationKit はこの乖離を埋めるためのライブラリです。

## The Goal（目標）

目標はシンプルです。

> **Architecture should be executable.**

現在の API では、次の形で振る舞いを定義します。

```text
State + Action
    ↓
Transition
    ↓
Next State
```

設計概念としての `Intent` は維持しつつ、公開 API の説明では `Action` / `ActionType` を優先します。

## Core Philosophy

- State は single source of truth
- 状態遷移は明示的・追跡可能であるべき
- StateMachine は Application layer に属し、UseCase を協調させる
- SwiftUI では Observation と `@Bindable` に自然に馴染むべき
- フルスタックフレームワークより軽量であるべき

## Architecture Overview

```text
SwiftUI View
   ↓
ScreenModel（任意）
   ↓
StateMachine
   ↓
UseCase / Domain
   ↓
Infrastructure
```

責務分離の目安:

| Layer | Responsibility |
| --- | --- |
| View | UI 描画 |
| ScreenModel | UI 入力の調停、Action 送信の集約 |
| StateMachine | 状態遷移とフロー制御 |
| UseCase | ドメインロジック |
| Infrastructure | 外部 I/O 実装 |

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

StateObservationKit は Application layer に置くことを前提にしています。状態変更は Machine の公開 API（`dispatch(_:)` / `send(_:)`）経由でのみ行い、具体的な Infrastructure 依存は UseCase や Environment 境界の外側に置きます。

## 例: 大きな ViewModel を避け、遷移を明示する

次のような「操作メソッドの集合」だけでは、振る舞いの全体像が見えにくくなります。

```swift
final class PlayerViewModel {
    func play() { /* ... */ }
    func pause() { /* ... */ }
    func stop() { /* ... */ }
}
```

StateObservationKit では、状態と Action を明示して遷移を定義します。

```swift
enum PlayerState: StateType {
    case idle
    case playing
    case paused
}

enum PlayerAction: ActionType {
    case play
    case pause
    case stop
}
```

```text
idle    --play-->  playing
playing --pause-> paused
paused  --play-->  playing
```

この形にすると、システムの振る舞いをレビューしやすく、テストしやすく、変更影響を追いやすくなります。

## Lightweight Alternative

StateObservationKit は「構造を得るための最小限の土台」を提供します。

- 明確な状態遷移
- アーキテクチャ起点の実装
- Observation-native な SwiftUI 連携

重い導入儀式なしに、段階的にアプリへ組み込めます。

## どんなときに向いているか

次の条件に当てはまる場合に特に有効です。

- 設計意図をコード上でも見える形で保ちたい
- 画面・機能に意味のある状態遷移がある
- ViewModel の肥大化を避けたい
- TCA より軽量な構成を選びたい

## サンプルアプリ戦略（記事作成前の下地）

README だけで終わらせず、導入判断しやすいサンプル群を整備します。

### 1. TodoApp（最優先）

- 目的: 最小構成で「Action -> Transition -> State」を理解できる入口
- 含める要素:
  - 追加 / 完了 / 削除の基本遷移
  - フィルタ切り替え（all / active / completed）
  - ScreenModel で入力集約、Machine は遷移専任

### 2. ChatApp

- 目的: 非同期イベントと順序保証の扱い方を示す
- 含める要素:
  - 送信中 / 送信成功 / 送信失敗の状態
  - follow-up action とリトライ
  - 無効遷移と effect failure のテスト

### 3. PlayerApp

- 目的: メディア操作のような明示遷移を UI に投影する例
- 含める要素:
  - `idle / playing / paused` の遷移
  - `canSend(_:)` でボタン活性を制御
  - `@Bindable` + projection による View の単純化

### サンプル共通方針

- 「動くだけ」ではなく、推奨アーキテクチャを示す
- View から直接状態を書き換えず、Machine API のみで遷移させる
- `ObservationDrivenStateMachineMock` を使った決定的テストを添える

## 現在の位置づけと読み分け

StateObservationKit は現在、ロードマップとアーキテクチャ文書に沿う形へ再整理を進めています。そのため、一部の文書には目標状態の説明が含まれており、current implementation はまだ旧来の API 形状を含んでいます。

どの文書を優先して読むか迷う場合は、次の順で判断してください。

1. `ROADMAP.ja.md`: プロジェクトの進行方向と目標アーキテクチャ
2. `docs/architecture.ja.md`: 設計境界と依存方向
3. この README: current public API の契約
4. 型の doc comment と tests: current runtime behavior

ロードマップと current implementation に差異がある場合、その差分は「修正対象の migration gap」として扱います。単なる文書誤記として処理しないでください。

## このパッケージが提供するもの

| 種別 | 目的 | 主な利用シーン |
| --- | --- | --- |
| `TransitionDrivenStateMachine` | 型安全な `enum` で遷移と副作用を明示化する | アプリケーションフロー、業務ロジック制御、オーケストレーション |
| `ObservationDrivenStateMachine` | UI 層向けに状態をリアクティブに公開し、Reducer 実行を逐次化する | SwiftUI と Observation を使う状態管理、`canSend` と projection を伴う UI 制御 |
| `ObservationDrivenStateMachineMock` | 非同期処理を排除し、同期的で決定的な状態検証を可能にする | ユニットテスト、UI テスト、プレビュー |
| `TransitionRecorder` | commit 済みの transition / action / state sequence を順序付きで記録する | 遷移履歴の検証、デバッグ、follow-up action の追跡 |
| `StateSequenceRecorder` | 任意の state 列を軽量に記録する | `hook` を使った状態列検証、プレビュー、簡易トレース |

## 用語対応

| アーキテクチャ上の概念 | 現在の API | 役割 |
| --- | --- | --- |
| State | `StateType` | 現在のアプリケーション状態を表す |
| Intent | `ActionType` | ユーザー入力やシステム入力を表す |
| Transition | `TransitionType` | 意味のある状態変化と必要なら副作用を定義する |
| Machine | `TransitionDrivenStateMachine` / `ObservationDrivenStateMachine` | 入力を解釈し、遷移を実行し、状態を公開する |

## 現在の Machine Contract

### `TransitionDrivenStateMachine`

- `dispatch(_:)` は状態変化を確定する唯一の公開入口です。
- 現在の `(state, action)` に一致する遷移がない場合は `TransitionDispatchError.invalidTransition` を投げ、状態は変わりません。
- 遷移の `effect` は `state` を確定する前に実行されます。
- `effect` が `CancellationError` 以外のエラーを投げた場合、状態は変わらず `TransitionDispatchError.effectFailed` を投げます。
- `effect` が follow-up の `Action` を返した場合、現在の遷移を確定してから、新しい状態に対して follow-up を dispatch します。
- `transitionRecorder` を渡すと、commit 済みの transition だけが記録されます。invalid transition や effect failure は履歴へ追加されません。

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

Q4 向けの薄い運用支援として、`TransitionRecorder` と `StateSequenceRecorder` を使うと commit 済みの履歴をそのままテストやデバッグに流せます。

```swift
let transitions = TransitionRecorder<PlayerTransition>()
let states = StateSequenceRecorder<PlayerState>()

let machine = TransitionDrivenStateMachine<PlayerTransition>(
    initial: .idle,
    hook: { states.record($0) },
    transitionRecorder: transitions
)

try await machine.dispatch(.play)

print(transitions.actions)       // [.play]
print(transitions.stateSequence) // [.idle, .playing]
print(states.snapshot)           // [.idle, .playing]
```

`TransitionRecorder` は state が commit された遷移だけを残すため、failure を含む effect のテストでも確定済みの履歴だけをアサートできます。

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
