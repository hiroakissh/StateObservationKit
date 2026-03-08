# 利用方法

StateObservationKit を使って状態駆動アプリを構築するための基本的な流れを紹介します。ここではタスク管理ドメインを例に、状態と入力の定義から View での利用までを順に説明します。
このガイドでは、アーキテクチャ上の `Intent` を current public API に合わせて `Action` / `ActionType` として記述します。

## 1. 状態と Action を定義する

```swift
enum TaskState: StateType {
    case idle
    case editing
    case saving
    case completed
    case error(String)
}

enum TaskAction: ActionType {
    case startEdit
    case save(String)
    case finish
    case fail(String)
}
```

- `StateType` と `ActionType` に準拠した `enum` を定義することで、遷移可能な状態と入力を列挙します。
- エラーやコンテキスト付きの情報は、関連値を活用して表現します。

## 2. ScreenModel で Machine と UseCase を束ねる

```swift
@Observable
@MainActor
final class TaskScreenModel {
    @ObservationIgnored
    private let machine: ObservationDrivenStateMachine<TaskState, TaskAction>
    @ObservationIgnored
    private let useCase: TaskUseCase

    init(useCase: TaskUseCase) {
        self.useCase = useCase
        self.machine = ObservationDrivenStateMachine(
            initial: .idle,
            canSend: Self.isActionAvailable(state:action:)
        ) { state, action in
            switch state {
            case .idle:
                switch action {
                case .startEdit:
                    state = .editing
                case .save, .finish, .fail:
                    break
                }
            case .editing:
                switch action {
                case .save:
                    state = .saving
                case .startEdit, .finish, .fail:
                    break
                }
            case .saving:
                switch action {
                case .finish:
                    state = .completed
                case .fail(let message):
                    state = .error(message)
                case .startEdit, .save:
                    break
                }
            case .completed:
                switch action {
                case .startEdit:
                    state = .editing
                case .save, .finish, .fail:
                    break
                }
            case .error:
                switch action {
                case .startEdit:
                    state = .editing
                case .save, .finish, .fail:
                    break
                }
            }
        }
    }

    var state: TaskState {
        machine.state
    }

    func canSend(_ action: TaskAction) -> Bool {
        machine.canSend(action)
    }

    func send(_ action: TaskAction) {
        switch action {
        case .startEdit:
            guard canSend(.startEdit) else { return }
            machine.dispatch(.startEdit)

        case .save(let title):
            guard canSend(.save(title)) else { return }
            machine.dispatch(.save(title))

            Task {
                let result = await Result<Void, Error>.catching {
                    try await useCase.saveTask(title)
                }

                await MainActor.run {
                    machine.dispatch(Self.followUpAction(for: result))
                }
            }

        case .finish, .fail:
            break
        }
    }

    nonisolated private static func isActionAvailable(
        state: TaskState,
        action: TaskAction
    ) -> Bool {
        switch (state, action) {
        case (.idle, .startEdit),
             (.editing, .save),
             (.saving, .finish),
             (.saving, .fail),
             (.completed, .startEdit),
             (.error, .startEdit):
            return true
        default:
            return false
        }
    }

    nonisolated private static func followUpAction(
        for result: Result<Void, Error>
    ) -> TaskAction {
        switch result {
        case .success:
            return .finish
        case .failure(let error):
            return .fail(error.localizedDescription)
        }
    }
}
```

- `ObservationDrivenStateMachine` には pure reducer を渡し、状態遷移だけを閉じ込めます。
- `canSend(_:)` を公開しておくと、View は `disabled` やナビゲーション制御を state から直接導けます。
- View からの入力は ScreenModel の `send(_:)` に集約し、副作用の結果は `Result` で受けて follow-up action に変換します。
- `default` を使わず、状態ごとに受け付ける Action を明示すると、状態追加時に見落としに気付きやすくなります。

### `send(_:)` と `dispatch(_:)` の役割

- `ObservationDrivenStateMachine.dispatch(_:)` は Machine の低レベル API で、入力を fire-and-forget に積む primitive です。
- `ObservationDrivenStateMachine.send(_:)` は同じ順序付きキューを await し、state 確定後に戻ります。
- ScreenModel の `send(_:)` は UI の入口で、入力の受理判定、UseCase 起動、`Result` から follow-up action への変換をまとめます。
- SwiftUI View からは ScreenModel の `send(_:)` を呼び、内部で必要なタイミングだけ `dispatch(_:)` / `send(_:)` を使うと、View に orchestration が漏れません。

### protocol と mock の使い分け

- ScreenModel が machine を保持する場合、`ObservationStateMachineType` を満たす型を init 境界で受けると、production では `ObservationDrivenStateMachine`、tests / previews では `ObservationDrivenStateMachineMock` を同じ構造で差し替えられます。
- `ObservationDrivenStateMachineMock` は `dispatch(_:)` / `send(_:)` の API 形状を合わせた同期 test double です。状態確認や preview には向きますが、queue の順序保証そのものを証明する用途には real machine を使ってください。

## 3. UseCase で副作用を扱う

```swift
actor TaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func saveTask(_ title: String) async throws {
        try await repository.save(Task(title: title))
    }
}
```

- UseCase は副作用やリポジトリ操作を一手に引き受け、テストしやすい構造を保ちます。
- 失敗時のエラー処理や follow-up action の判断は ScreenModel 側で `Result` を使って行い、Reducer には副作用を持ち込まないようにします。

## 4. View で状態を監視し Action を送出する

```swift
struct TaskView: View {
    @State private var model: TaskScreenModel
    @State private var newTitle = ""

    init(model: TaskScreenModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        let viewState = TaskViewProjection(
            state: model.state,
            canSave: model.canSend(.save(newTitle))
        )

        switch viewState.rendering {
        case .idle:
            Button("Start Editing") { model.send(.startEdit) }

        case .editing:
            VStack {
                TextField("Title", text: $newTitle)
                Button("Save") { model.send(.save(newTitle)) }
                    .disabled(!viewState.canSave)
            }

        case .saving:
            ProgressView("Saving...")

        case .completed:
            VStack {
                Text("✅ Task Saved")
                Button("Edit Again") { model.send(.startEdit) }
            }

        case .error(let message):
            VStack {
                Text("❌ \(message)").foregroundStyle(.red)
                Button("Retry") { model.send(.startEdit) }
            }
        }
    }
}

struct TaskViewProjection {
    enum Rendering {
        case idle
        case editing
        case saving
        case completed
        case error(String)
    }

    let rendering: Rendering
    let canSave: Bool

    init(state: TaskState, canSave: Bool) {
        self.canSave = canSave

        switch state {
        case .idle:
            self.rendering = .idle
        case .editing:
            self.rendering = .editing
        case .saving:
            self.rendering = .saving
        case .completed:
            self.rendering = .completed
        case .error(let message):
            self.rendering = .error(message)
        }
    }
}
```

- `@Bindable` で ScreenModel を監視し、その内部が持つ machine の状態を `switch` で描画します。
- `TaskViewProjection` のような UI projection を作ると、表示用フラグや文言を Domain 寄りの state に混ぜずに済みます。
- ボタン操作などのユーザー入力は `TaskScreenModel.send(_:)` に集約し、View から reducer や repository へ直接触れない形を保ちます。

```swift
let model = TaskScreenModel(useCase: .init(repository: TaskRepositoryImpl()))
TaskView(
    model: model
)
```

- SwiftUI sample でも同様に、View は ScreenModel の `send(_:)` を呼び、ScreenModel が `ObservationDrivenStateMachine` と UseCase を仲介します。

## 5. 値編集を Action に変換する

フォームの値そのものを state に保持している場合は、`binding(_:send:)` を使って SwiftUI の `Binding` を Action へ変換できます。

```swift
struct EditorState: Equatable, Sendable {
    var draftTitle = ""
}

enum EditorAction: ActionType {
    case titleChanged(String)
}

let machine = ObservationDrivenStateMachine<EditorState, EditorAction>(
    initial: EditorState()
) { state, action in
    switch action {
    case .titleChanged(let title):
        state.draftTitle = title
    }
}

TextField(
    "Title",
    text: machine.binding(\.draftTitle, send: EditorAction.titleChanged)
)
```

このパターンを使うと、View は値の変更を直接 state に書き込まず、常に Action 経由で扱えます。

これらの手順をベースに、ドメイン固有の状態・入力・副作用を組み合わせることで、状態駆動なアプリケーションを段階的に構築できます。
