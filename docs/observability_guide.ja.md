# Observation 観測・デバッグガイド

`ObservationDrivenStateMachine` は、UIへ公開する状態だけでなく、Actionの実行順序も開発時に観測できます。観測は状態変更の経路から分離され、Reducer queueの順序保証を維持します。

## イベントのライフサイクル

各Actionは次の順序で記録されます。

```text
enqueued
   ↓
started
   ↓
committed / rejected
```

- `enqueued`: Actionが順序付きqueueへ追加された
- `started`: 先行Actionのcommit後にReducer実行を開始した
- `committed`: Reducerが受理され、次のStateが公開された
- `rejected`: `canSend` がfalseで、Stateを変更せず完了した

## Recorder

```swift
let recorder = ObservationTraceRecorder<FormSubmissionState, FormSubmissionAction>()

let machine = ObservationDrivenStateMachine(
    initial: .idle,
    canSend: { state, action in
        FormSubmissionExample.canSend(state: state, action: action)
    },
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    },
    traceRecorder: recorder
)

_ = await machine.send(.start)

recorder.snapshot              // ordered lifecycle events
recorder.acceptedActions       // committed actions only
recorder.stateSequence         // initial state + committed states
```

`ObservationTraceRecorder` はスレッドセーフなスナップショットを提供します。失敗や無効入力を含めた実行順序を調べるときは `snapshot` を使い、確定した状態列だけを検証するときは `stateSequence` を使います。

## Logger

ログ出力先はアプリケーション側で決められます。

```swift
let logger = ObservationTraceLogger { message in
    print("[Form] \(message)")
}

let machine = ObservationDrivenStateMachine(
    initial: .idle,
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    },
    logger: logger
)
```

Appleプラットフォームでは unified logging に接続できます。

```swift
let logger = ObservationTraceLogger(
    subsystem: "com.example.player",
    category: "state-machine"
)
```

LoggerのsinkはMachineのMainActor上で呼ばれるため、重い処理や同期I/Oは避け、必要なら別の非同期ログ基盤へ渡してください。

## Debug Overlay

ObservationとSwiftUIが利用できる環境では、Machineの状態、最後のAction、Reducerのphase、pending数を表示できます。

```swift
let model = TimerExampleScreenModel()

ZStack(alignment: .bottomTrailing) {
    TimerExampleView(model: model)

    ObservationDebugOverlay(machine: model.machine)
        .padding()
}
```

これは開発用の表示です。公開ビルドへ含める場合は、アプリ側のDebugフラグや条件付きコンパイルで囲んでください。

## 実運用向けTimerサンプル

`TimerExampleScreenModel` と `TimerExampleView` は次を1つの構成で示します。

- pure reducerによる明示的なTimer状態遷移
- Application layerが所有するキャンセル可能なticker
- `ObservationTraceRecorder` による状態列の記録
- `ObservationDebugOverlay` による開発時表示

ソースは [TimerExample.swift](../Sources/StateObservationKit/SwiftUIExample/TimerExample.swift) を参照してください。実アプリではtickerの時間源をClockやUseCase Protocolへ差し替えると、時間依存をテストから隔離できます。

SwiftPMからサンプルアプリのターゲットをビルドする場合は、リポジトリルートで `swift build --product StateObservationKitTimerExample` を実行します。ターゲットの起動構成は [TimerExampleApp.swift](../Examples/TimerApp/TimerExampleApp.swift) を参照してください。

## テスト方針

- queueの順序とcommit semanticsは実機の`ObservationDrivenStateMachine`で検証する
- reducerやScreenModelの状態アサーションは`ObservationDrivenStateMachineMock`で決定的に検証する
- Loggerはイベント数とメッセージ形式を確認し、ログ出力先そのものはアプリ側でテストする
- Debug Overlayは状態ごとの表示と、Action送出がViewに閉じていることを確認する
