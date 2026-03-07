# コントリビューションガイド

StateObservationKit への貢献を歓迎します。本ガイドでは、Pull Request を作成する際の基本的な方針と、レビューで重視するポイントを示します。

## 参照優先順位

新しい作業では、現在の実装だけでなく次の文書を優先して参照してください。

1. `ROADMAP.ja.md`
2. `docs/architecture.ja.md`
3. `README.ja.md`
4. `docs/best_practices.md`
5. `docs/q1_execution_plan.ja.md`

ロードマップと current implementation に差異がある場合、その差異は「直すべき移行対象」として扱います。現状追認ではなく、ロードマップに沿ってどこを更新するべきかを先に整理してください。

## 開発方針
- 新しい StateMachine 型を追加する場合は、`ObservationDrivenStateMachine` または `TransitionDrivenStateMachine` を拡張し、既存の API と一貫した設計を保ってください。
- 状態や入力を追加する際は、すべてのケースを列挙したテストを用意し、`default` ケースに依存しない遷移を保証してください。
- `docs/architecture.md` に記載の依存方向 `View -> StateMachine -> UseCase / Domain -> Infrastructure` を満たしていることを確認してください。
- Q1 の変更では、対象タスクを `docs/q1_execution_plan.ja.md` の Milestone / Issue に紐付けてから着手してください。

## コード品質
- 副作用を伴う処理は UseCase で実装し、StateMachine では `dispatch(_:)` を通じた状態制御に集中してください。
- Observation 対応のコンポーネントでは、`@Observable` / `@Bindable` を適切に適用し、`canImport` ガードを忘れないようにします。
- テストでは `Testing/` 配下のモックやスタブを活用し、副作用のない状態遷移ロジックを重点的に検証してください。
- 設計概念の説明には `Intent` を使ってよいですが、current public API を説明する場合は `Action` / `ActionType` を優先してください。

## Pull Request の流れ
1. 変更内容を roadmap のどの四半期と Issue に対応づけるか明記します。
2. 実装だけでなく、必要なドキュメントやサンプルコードを同じ変更で更新します。
3. 標準 validation として `./scripts/validate.sh` を実行します。
4. Reviewer からのフィードバックを取り込み、依存方向、用語の一貫性、テストの網羅性を再確認してください。

## Validation Standard

Q1 の標準 validation は次の 2 コマンドです。通常は個別実行ではなく `./scripts/validate.sh` を使ってください。

```bash
swift test
swift build -Xswiftc -strict-concurrency=complete
```

- コード変更、public API 変更、sample 変更、test 変更を含む場合は `./scripts/validate.sh` を実行してください。
- docs-only change でローカルの Swift 検証を省略する場合は `./scripts/validate.sh docs-only` を使い、PR 本文や進捗報告に skip reason を明記してください。
- CI は `.github/workflows/swift-test.yml` から同じ script を呼び出す前提で維持します。ローカルと CI で別の検証手順を増やさないようにしてください。

## Repo-local Skill

このリポジトリ固有の planning / review / implementation ルールは `.codex/skills/` 配下を正本とします。

- `.codex/skills/state-observation-roadmap/SKILL.md`
- `.codex/skills/state-observation-roadmap/references/phase-checklist.md`
- `.codex/skills/state-observation-roadmap/references/review-checklist.md`

ロードマップ準拠の作業では、グローバル skill よりもこの repo 内の定義を優先してください。

## ライセンスとコミュニケーション
- すべての貢献はプロジェクトのライセンスに従います。
- 質問や提案は Issue で議論するか、ディスカッションチャンネルがある場合はそちらを活用してください。
- コードスタイルや設計上の判断が不明な場合は、既存実装やドキュメントを参照し、必要に応じて提案を添えて相談してください。

一貫した状態駆動設計を維持するため、上記方針に沿ったコントリビューションをお待ちしています。
