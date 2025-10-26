# AGENTS

このリポジトリを扱う自動化エージェント向けの手順をまとめています。

- 指示言語と同じ言語で返答を行なってください。
- `make_pr` を呼び出す前に必ず `git commit` を完了させてください。

## TransitionDrivenStateMachine モジュール生成

1. `instruction/1_TransitionDrivenStateMachine_Instruction.md` を読み、ディレクトリ/ファイル/テスト構成を確認する。
2. 指示書どおりに Core プロトコル、ステートマシン本体、サンプル Player ドメイン、テストを生成する。
3. 生成後は `swift test` を実行し、ログが想定どおりかチェックする。

## ObservationDrivenStateMachine 追加指針

- Observation フレームワークが利用できる環境では `@Observable` を付与し、利用できない場合でもビルドが通るよう条件付きコンパイルを用いる。
- SwiftUI サンプルは `canImport(SwiftUI)` と `canImport(Observation)` の両方を満たす場合のみビルドされるようにする。
- 既存の `PlayerState` / `PlayerAction` との重複定義を避け、共通ドメインモデルを参照する。
- テストや UI 層で依存差し替えができるよう、StateMachine はプロトコルを介してモック化できる構造を保つ。

## コーディング方針

- 遷移は `enum` ケースで必ず明示すること。
- 副作用は各遷移の `effect` プロパティに定義し、async/await と throws を許可する。
- 状態遷移は `dispatch(_:)` のみから行い、直接 `state` を書き換えない。
- Hook は View 通知やログなど軽量用途のみに使用し、重い処理は Effect に寄せる。

## テストとリリース

- `swift test` で PlayerExample の遷移ログを確認する。
- 検証完了後は `git tag 0.1.0` を作成し、必要に応じてリモートに push する。

## 将来の拡張

- Observation 統合 (`@ObservableStateMachine`) と Middleware 追加を後続タスクとして計画しているため、構成を拡張しやすい形で保つこと。
