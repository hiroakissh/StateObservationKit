# StateObservationKit Roadmap 2026

[English](ROADMAP.md) | [README](README.ja.md) | [アーキテクチャ](docs/architecture.ja.md)

このロードマップは、2026年を通じた StateObservationKit の目指す方向を示すものです。厳密なリリース契約ではなく、プロジェクトの進行方向と設計思想を共有するための文書として位置付けます。

## Vision

StateObservationKit は、SwiftUI 向けの state-driven application architecture を導入することを目指します。

フラグ、コールバック、ViewModel にアプリケーションの振る舞いを分散させるのではなく、ビジネスロジックを制御する中心を状態遷移に置きます。

このフレームワークは次の性質を目標にします。

- SwiftUI Observation と自然に連携できる
- Clean Architecture に組み込みやすい
- MVVM に対する state-machine-based な代替を提示できる
- TCA のような包括的フレームワークより軽量かつ単純である

## Core Philosophy

StateObservationKit は、次の原則を軸に設計します。

### 1. State is the source of truth

アプリケーションの振る舞いは、散在した条件分岐ではなく、現在の状態と意図によって決まるべきです。

```text
Current State + Intent
          ↓
      Transition
          ↓
      Next State
```

現在の API では、`Intent` という概念は `Action` として表現されています。

### 2. State transitions should be explicit

コールバックや ViewModel の内部に隠れた暗黙的な振る舞いではなく、遷移は可視化され、構造化され、検査できるべきです。

### 3. Clean Architecture compatibility

StateMachine は Domain layer ではなく Application layer に属します。

```text
View
 ↓
Application State Machine
 ↓
UseCase / Domain
 ↓
Infrastructure
```

### 4. SwiftUI-first ergonomics

Observation や `@Bindable` を活かし、SwiftUI から自然に使える体験を優先します。

### 5. Keep architecture lightweight

不要な儀式、過剰な抽象化、強いロックインは避けます。

## Roadmap Overview

| 四半期 | テーマ |
| --- | --- |
| 2026 Q1 | Core Architecture Stabilization |
| 2026 Q2 | Clean Architecture Integration |
| 2026 Q3 | SwiftUI Ergonomics and Tooling |
| 2026 Q4 | Production Readiness and Ecosystem |

## 2026 Q1: Core Architecture Stabilization

**Goal**  
コアとなるアーキテクチャモデルを定義し、基礎 API を安定化する。

### Focus Areas

**コア概念の定義**

次の語彙を明確化します。

- State
- Intent
- Transition
- Machine

```text
Intent
  ↓
Transition Decision
  ↓
Effect / UseCase
  ↓
Next State
```

**API の単純化**

次の API の責務と表面積を整理します。

- `TransitionDrivenStateMachine`
- `ObservationDrivenStateMachine`

責務整理:

| Component | Responsibility |
| --- | --- |
| State | アプリケーション状態を表す |
| Intent | ユーザーまたはシステムからの入力を表す |
| Transition | 意味のある状態変化を表す |
| Machine | 入力を解釈し、遷移を実行する |

**ドキュメント整備**

基礎ドキュメントを公開します。

- アーキテクチャ概要
- MVVM vs TCA vs StateObservationKit
- ステートマシンを採用すべき場面

### Deliverables

- 更新された README
- アーキテクチャ図
- コンセプトドキュメント

## 2026 Q2: Clean Architecture Integration

**Goal**  
StateObservationKit を Clean Architecture プロジェクトに自然に組み込めるようにする。

### Focus Areas

**Dependency Injection**

Environment ベースの依存管理を導入します。

```swift
struct PlayerEnvironment {
    let audioService: AudioServiceProtocol
}
```

Machine は Infrastructure 実装を直接参照しないようにします。

**UseCase Integration**

Machine と UseCase を接続するパターンを提供します。

```text
Intent
  ↓
Machine
  ↓
UseCase
  ↓
Next State
```

**Layer Separation Guide**

各レイヤーの責務を整理したガイドを公開します。

| Layer | Responsibility |
| --- | --- |
| Domain | ビジネスルール |
| Application | StateMachine |
| Infrastructure | 外部依存 |
| UI | 描画とユーザー操作 |

### Deliverables

- Clean Architecture 統合サンプル
- 依存注入サポート
- UseCase 統合パターン

## 2026 Q3: SwiftUI Ergonomics and Tooling

**Goal**  
SwiftUI アプリケーションで非常に使いやすい状態管理体験を提供する。

### Focus Areas

**SwiftUI Integration**

次のような SwiftUI 向けの使い勝手を改善します。

- `@Bindable` での Machine 利用
- Intent 送信ヘルパー
- Binding 生成
- SwiftUI 向けの state access

```swift
@Bindable var machine: PlayerMachine

Button("Play") {
    machine.send(.playTapped)
}
```

**Intent Availability**

操作可能性を公開します。

```swift
machine.canSend(.pauseTapped)
```

これにより、ボタンの disabled 状態やコントロールの活性状態を自然に UI へ反映できます。

**UI Projection**

任意の UI projection layer を導入します。

```text
Domain State
   ↓
Presentation Projection
   ↓
SwiftUI View
```

これにより、UI 都合の表現がドメイン向け状態に漏れ出すのを防ぎます。

### Deliverables

- SwiftUI 統合ユーティリティ
- Intent availability チェック
- UI projection パターン

## 2026 Q4: Production Readiness and Ecosystem

**Goal**  
実運用で採用できるだけの機能と周辺ツールを整える。

### Focus Areas

**Transition Recording**

遷移履歴の記録機能を導入します。

```text
Intent
 ↓
Transition
 ↓
State Change
 ↓
Recorded Event
```

想定用途:

- デバッグ
- 分析
- テスト
- time-travel debugging

例:

```text
Idle
 ↓ startTapped
Running
 ↓ pauseTapped
Paused
```

**Debugging Tools**

次のようなデバッグ支援を提供します。

- transition logger
- state change tracing
- development debug overlays

**Example Applications**

実運用に近いサンプルアプリを整備します。

| Example | Purpose |
| --- | --- |
| Timer App | 代表的な state machine サンプル |
| Coffee Brew Flow | 複数段階ワークフロー |
| Authentication Flow | 実アプリのライフサイクル |
| Form Submission | 非同期状態遷移 |

**Testing Tools**

テスト支援を拡充します。

- transition assertions
- intent history
- state sequence testing

### Deliverables

- transition recorder
- debugging utilities
- example applications
- testing helpers

## Long-Term Vision

StateObservationKit は、SwiftUI 向けの state-driven application architecture を確立することを目指します。

既存フレームワークを置き換えることが目的ではなく、次を求めるチームに明確な選択肢を提供することを狙います。

- 明示的な状態遷移
- 強いビジネスロジック制御
- SwiftUI と相性の良い API
- Clean Architecture 互換性
- 軽量なアーキテクチャ

## Guiding Principles

StateObservationKit は、意図的に次を避けます。

**過度に複雑な抽象化**  
API は単純で予測可能に保ちます。

**アーキテクチャのロックイン**  
利用者が自分たちの構成を選べる自由を残します。

**重い儀式性**  
過剰なボイラープレートやフレームワーク固有の作法を要求しません。

## Project Goals for 2026

2026年末までに、StateObservationKit は次を目指します。

- 安定した state-machine-based architecture を確立する
- SwiftUI-first な開発体験を提供する
- 実運用に近いユースケースを示す
- 強いデバッグ支援とテスト支援を提供する
- state-driven applications における MVVM の代替案を提示する
