# アーキテクチャ

[English](architecture.md) | [README](../README.ja.md) | [ロードマップ](../ROADMAP.ja.md)

StateObservationKit は、SwiftUI プロジェクトにおける Application layer のためのステートマシンライブラリとして設計されています。アプリケーション全体を支配するフレームワークになることは目指しておらず、単一のプロジェクト構成を強制もしません。役割は明確です。状態遷移を協調し、状態を UI に公開し、副作用の境界をはっきり保つことです。

## アーキテクチャモデル

核となるモデルは意図的に小さく保ちます。

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

現在の API では、アーキテクチャ上の `Intent` は `Action` として表現されています。
この文書では、設計概念の説明には `Intent` を使い、current public API の説明には `Action` / `ActionType` を使います。

| 概念 | 現在の API | 役割 |
| --- | --- | --- |
| State | `StateType` | 現在のアプリケーション状態を表す |
| Intent | `ActionType` | ユーザーまたはシステムからの入力を表す |
| Transition | `TransitionType` | 意味のある状態変化と必要なら副作用を定義する |
| Machine | `TransitionDrivenStateMachine` / `ObservationDrivenStateMachine` | 入力を解釈し、状態変化を確定する |

## レイヤー上の位置づけ

StateObservationKit は Application layer に置くことを想定しています。

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

この配置には意図があります。

- View は状態を描画し、入力を送る
- StateMachine はフローを制御し、遷移判断を行う
- UseCase や Domain service は業務処理を実行する
- Infrastructure は I/O、永続化、ネットワーク、プラットフォーム API を扱う

## レイヤーごとの責務

| レイヤー | 責務 | 主な要素 |
| --- | --- | --- |
| UI / View | 状態の描画と入力送出 | SwiftUI View、Binding、Navigation trigger |
| Application State Machine | 状態遷移とワークフローの制御 | `TransitionDrivenStateMachine`、`ObservationDrivenStateMachine` |
| UseCase / Domain | ビジネスルールと業務処理の実行 | UseCase、Domain service、Entity、Validation rule |
| Infrastructure | 外部世界との接続 | Repository、API client、Storage、Clock、System service |

Clean Architecture の解釈を 1 つに固定するつもりはありません。UseCase を Application layer に置くチームもあれば、Domain とより明確に分離するチームもあります。重要なのは、StateMachine 自体が Infrastructure の境界を直接背負わないことです。

## 2 つの Machine スタイル

| 種別 | 向いている場面 | 特徴 |
| --- | --- | --- |
| `TransitionDrivenStateMachine` | 明示的なオーケストレーションと業務フロー制御 | 型付き遷移、任意の async effect、無効遷移ハンドリング |
| `ObservationDrivenStateMachine` | SwiftUI 向け状態公開とリアクティブ更新 | Observation フレンドリーな状態公開、Reducer の逐次実行、`@Bindable` 連携 |

両方のスタイルで同じドメインモデルを共有できます。必要な構造の強さに応じて選べるようにすることが、このパッケージの狙いです。

## 現在の Dispatch Semantics

### `TransitionDrivenStateMachine`

- 現在の `(state, action)` から遷移を解決し、一致しない場合は `TransitionDispatchError.invalidTransition` を投げます。
- `effect` は状態確定の前に実行されます。
- `effect` が失敗した場合、現在の状態は維持されます。
- follow-up の `Action` は、現在の遷移を確定したあとにのみ適用されます。

### `ObservationDrivenStateMachine`

- `dispatch(_:)` は入力を受け取ると即座に戻ります。
- Reducer 実行は内部で逐次化され、dispatch 順序を保ちます。
- 新しい状態は各 Reducer 実行の完了後に MainActor 上で公開されます。
- 現時点では、dispatch 済み入力に対する完了ハンドルや rejection result は公開していません。

## 統合ルール

### 1. 状態変更は `dispatch(_:)` を通す

状態変更は Machine の境界を通して行います。これにより、遷移の観測、テスト、追跡が容易になります。

### 2. 副作用は UseCase に委譲する

StateMachine は「いつ処理を走らせるか」を決めますが、外部とのやり取り自体は UseCase、Service、Repository の背後に置きます。

### 3. 依存は抽象を通して注入する

Machine から具体的な Infrastructure 実装を直接参照するのではなく、Protocol や Environment struct を使います。

```swift
struct PlayerEnvironment {
    let audioService: AudioServiceProtocol
}
```

### 4. 必要なら UI projection を分離する

UI 向けの整形や選択状態が Domain 寄りの state を汚し始めたら、presentation projection を追加します。

```text
Domain State
   ↓
Presentation Projection
   ↓
SwiftUI View
```

### 5. テストダブルはプロトコル経由で扱う

`ObservationStateMachineType` と `ObservationDrivenStateMachineMock` を使うことで、UI やアプリケーションコードは具体的な実行時挙動ではなく抽象に依存できます。

## SwiftUI エルゴノミクス

StateObservationKit は、プラットフォームが許す範囲で SwiftUI-first を意識しています。

- 利用可能な環境では Observation を使う
- `@Bindable` で扱いやすい構造を保つ
- View での state access を単純に保つ
- Reducer 実行を逐次化して順序を保証する

目標は、名前だけ変えた ViewModel パターンを作ることではありません。View が state を直接観測でき、明示的な入力を受け付ける Machine を自然に扱えるようにすることです。

## このプロジェクトが避けるもの

StateObservationKit は、意図的に次を避けます。

- 重いフレームワーク儀式
- 見えにくい制御フロー
- 強制的なアーキテクチャロックイン
- 基本的な状態変化に対する巨大な Macro や DSL

これにより、MVVM より明示的な状態管理を求めつつ、フルスタックなフレームワーク群までは望まないチームにとって、現実的な選択肢になります。

## ロードマップとの関係

現在のアーキテクチャは基礎線です。ロードマップではこれを次の 4 方向に拡張していきます。

- 概念ドキュメントの強化と API 安定化
- Clean Architecture 統合と依存注入の改善
- SwiftUI エルゴノミクスと intent availability の改善
- transition recording や debugging utilities などの本番運用支援

Q1 の安定化フェーズでは、ロードマップを目標方向、README と tests を current public contract の参照先として扱ってください。
両者に差異がある場合、その差分は計画された migration work として扱います。

詳細は [ROADMAP.ja.md](../ROADMAP.ja.md) を参照してください。
