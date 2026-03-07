# Q2 実行計画

この文書は `ROADMAP.ja.md` の `2026 Q2: Clean Architecture Integration` を、実装・ドキュメント・サンプル・テストを一体で進めるための実行計画に落とし込んだものです。

Q1 で定義した API 契約（`Action` / `ActionType` を含む current public contract）を維持しつつ、Q2 では「依存の境界」と「UseCase 統合の型」を強化します。

## Q2 の完了条件

- Machine が concrete infrastructure 実装へ直接依存しない構造を、API / docs / sample / tests で説明・実証できる。
- Environment / Protocol ベースの依存注入パターンが、`TransitionDrivenStateMachine` と `ObservationDrivenStateMachine` の両方で示されている。
- UseCase 統合の推奨パターン（入力受理、業務処理、follow-up action）が docs と sample で矛盾しない。
- テストで正常遷移だけでなく、無効遷移、effect failure、順序保証、mock 差し替えを検証し、依存差し替え時の挙動が説明できる。

## 現状ギャップ（Q2 観点）

- 依存注入は `PlayerEnvironment` などのサンプルで導入済みだが、実行計画レベルでのマイルストン管理が未整備。
- docs 上で「推奨統合パターン」は存在する一方、Q2 の deliverable（DI support / UseCase integration pattern / integration sample）を段階的に完了判定する導線が弱い。
- contributor が Q2 作業を着手する際、Q1 の実行計画に比べて参照すべき issue 粒度が不足している。

## ロードマップ / アーキテクチャ整合チェック（着手前・PR前）

Q2 の各 Issue は、着手前と PR 前に次のチェックを満たしていることを確認します。

- `ROADMAP.ja.md` の Q2 deliverable（Clean Architecture 統合サンプル / 依存注入サポート / UseCase 統合パターン）へ直接対応付けできる。
- `docs/architecture.ja.md` の依存方向 `View -> StateMachine -> UseCase / Domain -> Infrastructure` を破る実装やサンプルがない。
- StateMachine から concrete infrastructure へ直接依存せず、Protocol または Environment 経由で注入されている。
- public API の説明は `Action` / `ActionType` を優先し、設計概念の説明でのみ `Intent` を使っている。
- docs / sample / tests の3点で同じ責務分離（Machine=制御、UseCase=副作用）を示している。

## Q2 レビュー観点（Clean Architecture）

- **依存逆転が成立しているか**: UseCase や service が Protocol 経由で差し替え可能か。
- **境界が混線していないか**: View や Machine に infrastructure 詳細（永続化 SDK、ネットワーク client 実装）が漏れていないか。
- **テスト可能性が維持されているか**: mock 注入だけで副作用を隔離し、状態遷移を決定的に検証できるか。
- **順序保証が保たれているか**: Observation 系 reducer の逐次実行と dispatch/send semantics を壊す変更がないか。

## Milestones

| Milestone | 目的 | 主な成果物 | 依存 |
| --- | --- | --- | --- |
| M1 DI 境界の標準化 | Environment / Protocol 注入の基準を固定する | docs 更新、sample の注入境界整理、テスト方針追記 | なし |
| M2 UseCase 統合パターンの定着 | Machine と UseCase の責務分離を実装例で統一する | usage / integration_examples 更新、sample 追従、回帰テスト | M1 |
| M3 Layer Separation Guide の実運用化 | レイヤー責務を contributor が迷わない形にする | architecture/contributing の導線更新、レビュー観点の明文化 | M1 |
| M4 Q3/Q4 へ接続する拡張点の固定 | Q2 で追加した DI/UseCase 形状を次フェーズ拡張可能にする | migration note、拡張ポイント整理、追加テスト | M2, M3 |

## Issue Backlog

## M1 DI 境界の標準化

### Q2-M1-1 Environment 注入パターンの統一

- 目的: サンプル・テスト・docs で同じ注入境界を示し、依存方向違反を防ぐ。
- 対象: `Sources/StateObservationKit/PlayerExample.swift`, `Sources/StateObservationKit/SwiftUIExample/`, `docs/architecture.ja.md`, `docs/usage.md`
- 完了条件:
  - `View -> StateMachine -> UseCase / Domain -> Infrastructure` を破るコード例がない。
  - concrete infrastructure への直接参照が、注入境界の外に隔離されている。

### Q2-M1-2 Protocol ベース差し替えのテスト強化

- 目的: UseCase / service のモック差し替えが仕様として保証される状態にする。
- 対象: `Tests/StateObservationKitTests/TransitionDrivenStateMachineTests.swift`, `Tests/StateObservationKitTests/ObservationDrivenStateMachineTests.swift`
- 完了条件:
  - mock 差し替え時の遷移結果と副作用呼び出し順がテストで検証される。
  - effect failure 時に状態不変であることが再確認できる。

## M2 UseCase 統合パターンの定着

### Q2-M2-1 ScreenModel / Application 境界の整理

- 目的: UI 入力から UseCase 実行、Machine 更新までの経路を推奨形に統一する。
- 対象: `docs/usage.md`, `Sources/StateObservationKit/SwiftUIExample/PlayerView_ObservationDriven.swift`
- 完了条件:
  - View は描画と入力送出に集中し、副作用処理の詳細を持たない。
  - `send(_:)` / `dispatch(_:)` の使い分けが docs と sample で一致する。

### Q2-M2-2 Transition と UseCase の責務境界整理

- 目的: Transition の effect が orchestration に集中し、業務処理本体を UseCase 側へ寄せる。
- 対象: `Sources/StateObservationKit/PlayerExample.swift`, `docs/integration_examples.md`
- 完了条件:
  - effect 実装が「呼び出しタイミングの決定」と「結果の action 化」に集中している。
  - UseCase 側で副作用が完結し、テストダブルで隔離可能である。

## M3 Layer Separation Guide の実運用化

### Q2-M3-1 レイヤー責務ガイドの更新

- 目的: Clean Architecture 解釈の違いを許容しつつ、依存方向の最小ルールを固定する。
- 対象: `docs/architecture.ja.md`, `docs/architecture.md`, `docs/contributing.md`
- 完了条件:
  - レイヤー責務表とレビュー観点が一致する。
  - contributor が「どこに何を書くか」を判断できる。

### Q2-M3-2 統合サンプルカタログの精緻化

- 目的: 代表的ユースケース（永続化、ネットワーク、タイマー）で同一アーキテクチャを示す。
- 対象: `docs/integration_examples.md`
- 完了条件:
  - 各サンプルが共通の依存注入パターンで説明される。
  - anti-pattern（Machine から Infrastructure 直参照）を避ける注意点が明示される。

## M4 Q3/Q4 へ接続する拡張点の固定

### Q2-M4-1 Q3 互換の入力 API 検討メモ整備

- 目的: Q3 の ergonomics 改善（例: 操作可能性 API）を壊さない注入形状を事前に固定する。
- 対象: `ROADMAP.ja.md`, `docs/usage.md`, 必要なら設計ノート
- 完了条件:
  - Q2 で導入した境界が Q3 API 追加時の障害にならない。

### Q2-M4-2 Q4 観測性拡張の受け皿確認

- 目的: transition recording / logger 追加時に UseCase 境界と競合しない構成を確認する。
- 対象: core docs、tests
- 完了条件:
  - 監視用途の拡張点が state mutation 経路を汚さない。
  - 決定的順序保証を壊さない前提が文書化される。

## 推奨実行順

1. Q2-M1-1
2. Q2-M1-2
3. Q2-M3-1
4. Q2-M2-1
5. Q2-M2-2
6. Q2-M3-2
7. Q2-M4-1
8. Q2-M4-2

## Q2 でやらないこと

- Q3 の `@Bindable` ergonomics 最適化そのもの（Q2 では下地のみ）。
- Q3 の intent availability API の最終仕様確定。
- Q4 の transition recording / logger / testing helper の本実装。

Q2 では、機能追加を急ぐより先に「依存境界が崩れない統合方法」を標準化し、以降の四半期で拡張しても破綻しない構造を固める。
