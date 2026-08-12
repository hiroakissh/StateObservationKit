# 連携・統合サンプル

StateObservationKit を既存のアプリ基盤に組み合わせる際のヒントと、代表的な統合パターンを紹介します。各サンプルでは状態遷移と副作用の境界を明確にし、テスタブルな構造を維持することが重要です。

## FormSubmissionExample の依存注入

- `FormSubmissionUseCaseProtocol` が Application から見た副作用の境界です。Repository、API client、認証 SDK などの具体実装はこの Protocol の外側に置きます。
- `FormSubmissionEnvironment` は composition root から UseCase を受け取り、`FormSubmissionScreenModel` に渡します。ScreenModel や StateMachine 内で live Infrastructure を生成しません。
- `FormSubmissionExample.reduce` は pure reducer であり、`FormSubmissionExample.canSend` と組み合わせて入力可能性を明示します。
- `FormSubmissionScreenModel.sendAndWait(_:)` は UseCase の結果を `.succeeded` / `.failed` に変換する await 可能な orchestration 入口です。View では fire-and-forget の `send(_:)` を使えます。
- Preview とテストでは `InMemoryFormSubmissionUseCase` または `FormSubmissionUseCaseProtocol` の mock を渡し、live な副作用から状態遷移を分離します。

詳細な責務分担と composition root の作り方は [Clean Architecture 統合ガイド](clean_architecture_guide.ja.md) を参照してください。

## PlayerExample の依存分離
- `PlayerEnvironment` が `PlayerUseCaseProtocol` を保持し、StateMachine から concrete infrastructure を直接参照しない形を取ります。
- `PlayerUseCase` が `AudioServiceProtocol` を受け取り、`PlayerTransition` の effect は UseCase を通じて副作用を実行します。
- サンプルやテストでは `withPlayerExampleEnvironment(_:_:)` を使って現在の task scope だけ依存を差し替えられるため、状態遷移の検証時に live な audio 実装へ依存しません。
- `withPlayerExampleEnvironment(_:_:)` はネストやエラー時にも元の environment を自動復元し、並行実行のテストでも scoped override が混線しない形を取ります。

## ストップウォッチ / ポモドーロタイマー
- `StopwatchUseCase` が経過時間の計測とポモドーロサイクルの切り替えを担当します。
- StateMachine は `running` / `paused` / `break` などの状態を持ち、タイマーイベントを受けて遷移します。
- タイマーのトリガーは `AsyncStream` や `Clock` を用いて非同期に発火させ、結果をイベントとして StateMachine に送ります。
- 同梱の `TimerExampleScreenModel` は、純粋な reducer と Application layer 所有の cancellable ticker を組み合わせた実装例です。
- `TimerExampleView` では `ObservationDebugOverlay` を重ね、状態・最後の Action・pending 数を開発中に確認できます。

## AI プランニング連携
- Foundation Model への問い合わせを UseCase が担当し、リクエスト/レスポンスを Repository に委譲します。
- 推論状態 (`querying`, `receiving`, `failed`) を StateMachine で管理し、推論完了時に View に結果を表示します。
- 非同期のストリーミングレスポンスはイベントシーケンスとして StateMachine に流し込み、逐次状態を更新します。

## SwiftData 永続化との併用
- SwiftData や CoreData を用いた永続化処理を Repository に実装し、UseCase から呼び出します。
- StateMachine は `loading` / `loaded` / `saving` / `error` などの状態を持ち、永続化の進行度を UI に反映します。
- `Observation` と組み合わせることで、永続化結果が反映された状態を即座に View へ伝播できます。

## StateMachine のテスト設計
- イベントシーケンスを `dispatch` し、期待される状態遷移をアサートするテストを用意します。
- 非同期副作用は UseCase や Repository をモック化し、期待するイベントの発火を検証します。
- Observation系では `ObservationTraceRecorder` で `enqueued` → `started` → `committed` / `rejected` の順序を検証できます。
- `ObservationTraceLogger` は print、OS unified logging、アプリ独自のログ基盤へ接続できます。
- `TransitionDrivenStateMachine` では `TransitionRecorder` を渡すと、commit 済みの `actions` / `transitions` / `stateSequence` を順序付きで取得できます。follow-up action を含むフローの検証に向きます。
- `StateSequenceRecorder` を `hook` と組み合わせると、状態列だけを軽量に検証できます。invalid transition や effect failure を含むケースでも、確定済み state のみを追跡しやすくなります。
- `Testing/ObservationDrivenStateMachineMock` を活用して Reducer のロジックのみを検証し、副作用を排除した純粋なテストを実現します。
- UI / ScreenModel が machine を保持する場合は `ObservationStateMachineType` を注入境界に置き、production では real machine、preview / state assertion では mock を差し替える形にすると一貫します。

これらのサンプルを参考に、ドメイン固有のユースケースを組み合わせることで、状態駆動設計のメリットを最大限引き出せます。
