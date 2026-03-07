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
        self.machine = ObservationDrivenStateMachine(initial: .idle) { state, action in
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

    func send(_ action: TaskAction) {
        switch action {
        case .startEdit:
            machine.dispatch(.startEdit)
        case .save(let title):
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
- View からの入力は ScreenModel の `send(_:)` に集約し、副作用の結果は `Result` で受けて follow-up action に変換します。
- `default` を使わず、状態ごとに受け付ける Action を明示すると、状態追加時に見落としに気付きやすくなります。

### `send(_:)` と `dispatch(_:)` の役割

- `ObservationDrivenStateMachine.dispatch(_:)` は Machine の低レベル API で、入力を fire-and-forget に積む primitive です。
- `ObservationDrivenStateMachine.send(_:)` は同じ順序付きキューを await し、state 確定後に戻ります。
- `send(_:)` は UI / ScreenModel 側の入口で、入力の受理判定、UseCase 起動、`Result` から follow-up action への変換をまとめます。
- SwiftUI View からは `send(_:)` を呼び、ScreenModel の内部で必要なタイミングだけ `dispatch(_:)` を使うと、View に orchestration が漏れません。

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

        switch model.state {
        case .idle:
            Button("Start Editing") { model.send(.startEdit) }

        case .editing:
            VStack {
                TextField("Title", text: $newTitle)
                Button("Save") { model.send(.save(newTitle)) }
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
```

- `@Bindable` で ScreenModel を監視し、その内部が持つ machine の状態を `switch` で描画します。
- ボタン操作などのユーザー入力は `TaskScreenModel.send(_:)` に集約し、View から reducer や repository へ直接触れない形を保ちます。
- つまり View は intent を送るだけで、実際の state commit は ScreenModel 内の `dispatch(_:)` が担当します。

```swift
let model = TaskScreenModel(useCase: .init(repository: TaskRepositoryImpl()))
TaskView(
    model: model
)
```

- SwiftUI sample でも同様に、View は ScreenModel の `send(_:)` を呼び、ScreenModel が `ObservationDrivenStateMachine` と UseCase を仲介します。

これらの手順をベースに、ドメイン固有の状態・入力・副作用を組み合わせることで、状態駆動なアプリケーションを段階的に構築できます。
