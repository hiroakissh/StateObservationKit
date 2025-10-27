# 連携・統合サンプル

StateObservationKit を既存のアプリ基盤に組み合わせる際のヒントと、代表的な統合パターンを紹介します。各サンプルでは状態遷移と副作用の境界を明確にし、テスタブルな構造を維持することが重要です。

## ストップウォッチ / ポモドーロタイマー
- `StopwatchUseCase` が経過時間の計測とポモドーロサイクルの切り替えを担当します。
- StateMachine は `running` / `paused` / `break` などの状態を持ち、タイマーイベントを受けて遷移します。
- タイマーのトリガーは `AsyncStream` や `Clock` を用いて非同期に発火させ、結果をイベントとして StateMachine に送ります。

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
- `Testing/ObservationDrivenStateMachineMock` を活用して Reducer のロジックのみを検証し、副作用を排除した純粋なテストを実現します。

これらのサンプルを参考に、ドメイン固有のユースケースを組み合わせることで、状態駆動設計のメリットを最大限引き出せます。
