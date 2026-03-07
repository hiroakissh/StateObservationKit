# AGENTS

このリポジトリを扱う自動化エージェント向けの手順です。

- 指示と同じ言語で返答すること。
- `make_pr` を呼び出す前に必ず `git commit` を完了させること。

## 参照優先順位

新しい作業では、既存実装よりも次の文書を優先して判断すること。

1. `ROADMAP.ja.md`
2. `docs/architecture.ja.md`
3. `README.ja.md`
4. `docs/best_practices.md`
5. `docs/contributing.md`

- ロードマップと現行実装に差異がある場合、その差異は「今後解消すべき移行対象」とみなすこと。
- アーキテクチャ概念としては `Intent` を使ってよいが、現行公開 API を説明する際は `Action` / `ActionType` を優先すること。

## プロジェクト専用 Skills

- このプロジェクト固有の Skill は `.codex/skills/` 配下を正本とすること。
- ロードマップ準拠の planning / review / implementation を行うときは `.codex/skills/state-observation-roadmap/SKILL.md` を参照すること。
- グローバルな `$CODEX_HOME/skills` に同名 Skill が存在しても、このリポジトリ内の定義を優先すること。

## 基本ワークフロー

1. 対象タスクを `ROADMAP.ja.md` の Q1〜Q4 のどこに属するか分類する。
2. Q1 の作業では `docs/q1_execution_plan.ja.md` を確認し、対象 Milestone / Issue を紐付ける。
3. 対応する設計文書を確認し、変更対象を API / docs / sample / tests のどれかに分解する。
4. 実装差分だけでなく、必要なドキュメントとサンプルコードの追従も同一変更で扱う。
5. 変更後は `./scripts/validate.sh` を標準検証入口として使うこと。
6. docs-only change でローカルの Swift 検証を省略する場合は `./scripts/validate.sh docs-only` を使い、skip reason を PR や作業報告に明記すること。

## アーキテクチャルール

- 依存方向は `View -> StateMachine -> UseCase / Domain -> Infrastructure` を守ること。
- StateMachine から具体的な Infrastructure 実装を直接参照しないこと。依存は Protocol または Environment 経由で注入すること。
- 状態変更は Machine の公開 API (`dispatch(_:)` や将来の送信 API) を通してのみ行い、外部から直接 `state` を書き換えないこと。
- 遷移・状態・入力は明示的に列挙し、`default` ケースで網羅性を逃がさないこと。
- サンプルコードは「動く例」よりも「推奨アーキテクチャの例」を優先すること。
- Observation 対応は `canImport(Observation)`、SwiftUI サンプルは `canImport(SwiftUI) && canImport(Observation)` を守ること。
- Observation 系の reducer 実行順序は決定的でなければならない。順序保証を壊す並行更新を持ち込まないこと。

## フェーズ別の実装方針

### Q1 Core Architecture Stabilization

- 用語、責務、公開 API の意味を先に固めること。
- README、architecture、usage の記述が互いに矛盾しない状態を保つこと。
- docs のコード例は現行 API と整合するよう維持すること。

### Q2 Clean Architecture Integration

- Machine には Environment、Protocol、UseCase など抽象境界を持たせること。
- UseCase 統合例と依存注入パターンを docs / sample に反映すること。

### Q3 SwiftUI Ergonomics and Tooling

- `@Bindable`、操作可能性、Binding 生成、UI projection を扱う変更では SwiftUI 利用時の ergonomics を最優先に考えること。
- View は状態を直接監視し、状態ごとの描画を `switch` で明示すること。

### Q4 Production Readiness and Ecosystem

- transition recording、logger、testing helper は観測性とデバッグ性を高める形で追加すること。
- サンプルアプリやテスト支援は本番利用を意識した API の見本にすること。

## テストルール

- 遷移の正常系だけでなく、無効遷移、effect failure、順序保証、follow-up action、mock 差し替えも検証すること。
- `ObservationDrivenStateMachineMock` のようなテストダブルを優先し、副作用は隔離すること。
- `sleep` に依存するテストは暫定措置として扱い、より決定的な完了通知や await 可能 API に置き換えられないか検討すること。
- 標準 validation は `./scripts/validate.sh` とし、その中で `swift test` と `swift build -Xswiftc -strict-concurrency=complete` を実行すること。
- docs-only change でコンパイルを省略した場合でも、skip は例外扱いとして明示すること。

## レビュー観点

- 変更はロードマップのどの四半期の deliverable に対応しているか。
- 用語の一貫性が保たれているか。
- docs / sample / tests / public API が同じ設計方針を示しているか。
- サンプルやテストがアーキテクチャ違反を教える形になっていないか。

## リリース

- タグ作成やリリース作業は、ユーザーが明示的に求めた場合のみ行うこと。
