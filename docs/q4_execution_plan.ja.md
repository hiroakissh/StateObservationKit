# Q4 実行計画

この文書は `ROADMAP.ja.md` の 2026 Q4「Production Readiness and Ecosystem」を、TransitionDriven と ObservationDriven の両方を対象にした実装計画へ落とし込みます。

## 目的

- commit 済みの状態遷移を順序付きで記録する
- Observation の Action lifecycle と reducer queue の完了点を観測する
- 開発時の logger と SwiftUI debug overlay を提供する
- 実運用に近いサンプルで、副作用・キャンセル・状態表示の境界を示す

## Milestones

| Milestone | 目的 | 成果物 | 状況 |
| --- | --- | --- | --- |
| M1 Transition recording | 明示的な遷移の履歴を保存する | `TransitionRecorder`, `StateSequenceRecorder`, transition tests | 実装済み（0.3.0実装を統合） |
| M2 Observation tracing | Observation Actionのqueue lifecycleを記録する | `ObservationTraceEvent`, `ObservationTraceRecorder`, trace tests | 実装済み |
| M3 Logging / Debug Overlay | 開発時の状態観測をUI・ログへ接続する | `ObservationTraceLogger`, `ObservationDebugOverlay`, guide | 実装済み |
| M4 Example applications | 実運用に近い状態駆動の例を提供する | `TimerExampleScreenModel`, `TimerExampleView`, SwiftPM executable target, tests | 実装済み |
| M5 Testing and release gate | 仕様・ドキュメント・検証を揃える | roadmap update、標準validation、PR | 標準validation済み、Draft PR #29公開済み、CI確認中 |

## Observation event contract

各ActionのイベントはMachineのMainActor上で、reducer queueの順序と同じ順序で発火します。

```text
enqueued
   ↓
started
   ↓
committed / rejected
```

- `committed` のみ `nextState` を持ち、`stateSequence` に反映される。
- `rejected` は状態を変更せず、入力の拒否を履歴へ残す。
- logger、debug overlay、custom trace handlerは状態を変更しない。
- queueの順序自体はreal machineで検証し、mockはreducerとScreenModelの決定的な状態検証に使う。

## Q4で残す拡張候補

- transition recorderとObservation traceを共通のexport形式へ変換する
- trace eventへのtimestamp / correlation id付与
- debug overlayのAction履歴表示とrelease build除外ヘルパー
- Timer以外のAuthentication / Coffee Brew / Network Formサンプル
