# Q1 実行計画

この文書は `ROADMAP.ja.md` の `2026 Q1: Core Architecture Stabilization` を実装タスクに落とし込むための実行計画です。目的は、概念整理だけで終わらせず、docs、samples、tests、public API を同じ方向へ揃えることです。

## Q1 の完了条件

- `State` / `Intent` / `Transition` / `Machine` の語彙が README、architecture、usage、samples、tests で一貫している。
- `TransitionDrivenStateMachine` と `ObservationDrivenStateMachine` の責務と公開契約が文章とコードの両方で説明できる。
- 公式サンプルが推奨アーキテクチャに反しない。
- core test が正常系だけでなく、無効遷移、effect failure、順序保証を説明できる。

## Milestones

| Milestone | 目的 | 主な成果物 | 依存 |
| --- | --- | --- | --- |
| M1 用語と API 契約の固定 | Q1 の土台を固める | glossary、README / docs 更新、API contract 整理 | なし |
| M2 サンプルと docs の整合 | 推奨アーキテクチャをサンプルに反映する | Player sample、SwiftUI sample、usage 更新 | M1 |
| M3 Observation 契約とテスト安定化 | 並行性と reducer 実行の意味を安定させる | Observation API 調整、テスト改善、mock 利用整理 | M1 |
| M4 コントリビューション導線整備 | 以後の変更をロードマップ準拠に保つ | AGENTS、contributing、repo-local skill、CI/validation 整理 | M1 |

## Issue Backlog

## M1 用語と API 契約の固定

### Q1-M1-1 用語マッピングの確定

- 目的: `Intent` / `Action` / `Event` の扱いを固定し、公開 API と設計語彙の境界を明文化する。
- 対象: `README.md`, `README.ja.md`, `docs/architecture.md`, `docs/architecture.ja.md`, `docs/usage.md`, `docs/philosophy.md`
- 完了条件:
  - docs 間で用語の意味が矛盾しない。
  - aspirational な概念と current API が区別されている。

### Q1-M1-2 Machine contract の明文化

- 目的: `dispatch(_:)`、無効遷移、effect failure、follow-up action、state commit の意味を固定する。
- 対象: core docs、README、必要なら API doc comment
- 完了条件:
  - `TransitionDrivenStateMachine` の契約を README だけで説明できる。
  - `ObservationDrivenStateMachine` の dispatch semantics を docs で説明できる。

### Q1-M1-3 ドキュメントの優先順位と migration note の整理

- 目的: ロードマップと現行実装のズレを「誤記」ではなく「移行中の差分」として扱える状態にする。
- 対象: roadmap 関連 docs、contributing、AGENTS
- 完了条件:
  - 新規 contributor がどの文書を信じるべきか迷わない。

## M2 サンプルと docs の整合

### Q1-M2-1 PlayerExample の依存方向修正

- 目的: サンプルから直接的な infrastructure 参照を外し、UseCase / Environment / Protocol ベースの例へ寄せる。
- 対象: `Sources/StateObservationKit/PlayerExample.swift`, `docs/integration_examples.md`
- 完了条件:
  - Sample が `View -> StateMachine -> UseCase / Domain -> Infrastructure` を破らない。

### Q1-M2-2 SwiftUI sample の推奨構成化

- 目的: SwiftUI サンプルを「動く最短例」ではなく「推奨構成の最短例」に置き換える。
- 対象: `Sources/StateObservationKit/SwiftUIExample/PlayerView_ObservationDriven.swift`, `docs/usage.md`
- 完了条件:
  - `default` に依存しない。
  - UI から machine への入力経路が docs と一致する。

### Q1-M2-3 docs example のビルド整合性確認

- 目的: README / usage のコード片が current API と原理的に矛盾しない状態にする。
- 対象: `README.md`, `README.ja.md`, `docs/usage.md`
- 完了条件:
  - 少なくとも手で追えるレベルで API と齟齬がない。

## M3 Observation 契約とテスト安定化

### Q1-M3-1 Observation dispatch 完了モデルの決定

- 目的: fire-and-forget を維持するか、await 可能な送信 API を別途持つかを決める。
- 対象: `ObservationDrivenStateMachine.swift`, docs
- 完了条件:
  - reducer 実行完了をどう観測するかが文書化されている。

### Q1-M3-2 sleep 依存テストの削減

- 目的: 順序保証テストを任意待機時間から切り離す。
- 対象: `Tests/StateObservationKitTests/ObservationDrivenStateMachineTests.swift`
- 完了条件:
  - core behavior のテストが時間依存を最小化している。

### Q1-M3-3 mock / protocol 利用方針の固定

- 目的: UI 層とテスト層がどの抽象に依存すべきかを明確にする。
- 対象: `ObservationStateMachineType`, `ObservationDrivenStateMachineMock`, docs
- 完了条件:
  - docs とサンプルの依存注入方針が一致する。

## M4 コントリビューション導線整備

### Q1-M4-1 AGENTS と contributing の roadmap-first 化

- 目的: 以後の作業が古い生成前提へ戻らないようにする。
- 対象: `AGENTS.md`, `docs/contributing.md`
- 完了条件:
  - 新規タスクが roadmap と architecture を起点に整理される。

### Q1-M4-2 repo-local skill の配置

- 目的: planning / review / implementation のガードレールをこの repo の中に持つ。
- 対象: `.codex/skills/state-observation-roadmap/`
- 完了条件:
  - この repo だけで project-specific な運用ルールを参照できる。

### Q1-M4-3 validation 導線の整理

- 目的: `swift test` と strict concurrency build を Q1 の標準検証にする。
- 対象: `docs/contributing.md`, 必要なら CI
- 完了条件:
  - 最低限の検証コマンドが contributor に明示されている。

## 推奨実行順

1. Q1-M1-1
2. Q1-M1-2
3. Q1-M4-1
4. Q1-M2-1
5. Q1-M2-2
6. Q1-M2-3
7. Q1-M3-1
8. Q1-M3-2
9. Q1-M3-3
10. Q1-M4-2
11. Q1-M4-3
12. Q1-M1-3

## Q1 でやらないこと

- Q2 の本格的な DI API 追加
- Q3 の `canSend(_:)` や Binding 生成の完成
- Q4 の transition recorder や debug overlay の本実装

Q1 では「何を作るか」より先に「何を正しい形として説明し、どこまでが current contract か」を固める。
