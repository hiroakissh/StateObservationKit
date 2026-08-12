# Clean Architecture 統合ガイド

このガイドでは、StateObservationKit を既存アプリケーションへ組み込むときの最小構成を示します。ライブラリは Application layer の StateMachine を担当し、UseCase や Infrastructure の構成は利用側に残します。

依存方向は次の形にします。

```text
View
 ↓ Action
ScreenModel / Application StateMachine
 ↓
UseCase / Domain
 ↓
Repository / API Client / System Service
```

## 1. 境界を Protocol で定義する

StateMachine が永続化 SDK やネットワーク client を直接知るのではなく、Application が必要とする処理を UseCase Protocol として定義します。

```swift
protocol FormSubmissionUseCaseProtocol: Sendable {
    func submit(_ draft: FormSubmissionDraft) async throws
}

struct FormSubmissionEnvironment: Sendable {
    let useCase: any FormSubmissionUseCaseProtocol
}
```

`FormEnvironment` は画面や Machine の内側で live 実装を生成せず、composition root で組み立てます。

```swift
let environment = FormSubmissionEnvironment(
    useCase: InMemoryFormSubmissionUseCase()
)
let model = FormSubmissionScreenModel(environment: environment)
```

Preview とテストでは同じ Protocol に準拠した差し替えを渡します。

```swift
let model = FormSubmissionScreenModel(
    environment: FormSubmissionEnvironment(useCase: InMemoryFormSubmissionUseCase())
)
```

## 2. StateMachine は状態遷移だけを担当する

State と Action は、UI のフラグではなく業務フロー上の意味を持つ単位で定義します。

```swift
enum FormSubmissionState: StateType {
    case idle
    case editing(FormSubmissionDraft)
    case submitting(FormSubmissionDraft)
    case submitted(FormSubmissionDraft)
    case failed(FormSubmissionDraft, message: String)
}

enum FormSubmissionAction: ActionType {
    case start
    case titleChanged(String)
    case bodyChanged(String)
    case submit
    case succeeded
    case failed(String)
    case retry
    case reset
}
```

Observation を使う画面では、pure reducer と `canSend` を Machine に渡します。

```swift
let machine = ObservationDrivenStateMachine(
    initial: .idle,
    canSend: { state, action in
        FormSubmissionExample.canSend(state: state, action: action)
    },
    reducer: { state, action in
        FormSubmissionExample.reduce(state: &state, action: action)
    }
)
```

Reducer は UseCase を呼び出さず、状態の確定だけを行います。これにより reducer 単体テストと UseCase テストを分離できます。

## 3. ScreenModel が入力受理と UseCase を協調する

View は `ScreenModel.send(_:) ` だけを呼び、非同期処理の詳細を持ちません。

```swift
let model = FormSubmissionScreenModel(environment: .preview)
_ = await model.sendAndWait(.start)
_ = await model.sendAndWait(.titleChanged("Title"))
_ = await model.sendAndWait(.bodyChanged("Body"))
let finalState = await model.sendAndWait(.submit)
```

`FormSubmissionScreenModel.send(_:)` は UI 用の fire-and-forget 入口、`sendAndWait(_:)` は UseCase の結果を follow-up Action に変換し、完了した State を返す orchestration 入口です。実装は同梱の `FormSubmissionScreenModel` を参照してください。

## 4. TransitionDrivenStateMachine を使う場合

明示的な遷移 enum と async effect を使う構成では、UseCase を Environment から注入し、effect は呼び出しのタイミングと follow-up Action の変換だけを担当させます。

実際の構成は [PlayerExample](../Sources/StateObservationKit/PlayerExample.swift) と `PlayerEnvironment` を参照してください。`PlayerTransition.effect` は環境から `PlayerUseCaseProtocol` を取得して呼び出すだけに留まり、具体的な `AudioService` は UseCase の背後に隔離されています。

## 5. テストの境界

次の3層を分けてテストします。

| 対象 | 差し替えるもの | 確認すること |
| --- | --- | --- |
| Reducer | 依存なし | State + Action の遷移、無効入力 |
| ScreenModel | UseCase mock、Machine mock | 入力受理、UseCase呼び出し、follow-up |
| 実Machine | 依存なしまたはUseCase mock | reducerの順序、`send` の完了 semantics |

`ObservationDrivenStateMachineMock` は ScreenModel、Preview、状態アサーションに使います。Reducer queue の順序保証自体を検証するときは実機の `ObservationDrivenStateMachine` を使います。

## 避ける構成

- View から Repository や API Client を直接呼ぶ
- StateMachine 内で concrete Infrastructure を生成する
- UseCase の結果を View の callback だけで処理し、状態へ戻さない
- `default` で状態と Action の組み合わせを隠す

同梱の `FormSubmissionExample` は、このガイドの実行可能な最小例です。[integration_examples.md](integration_examples.md) と合わせて参照してください。
