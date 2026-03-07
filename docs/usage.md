# 利用方法

StateObservationKit を使って状態駆動アプリを構築するための基本的な流れを紹介します。ここではタスク管理ドメインを例に、状態と Action の定義から View での利用までを順に説明します。

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

## 2. StateMachine を定義する

```swift
@MainActor
final class TaskStateMachine {
    let machine: ObservationDrivenStateMachine<TaskState, TaskAction>
    private let useCase: TaskUseCase

    init(useCase: TaskUseCase) {
        self.useCase = useCase
        self.machine = ObservationDrivenStateMachine(
            initial: .idle,
            canSend: { state, action in
                switch (state, action) {
                case (.idle, .startEdit),
                     (.editing, .save),
                     (.saving, .finish):
                    return true
                case (_, .fail):
                    return true
                default:
                    return false
                }
            }
        ) { state, action in
            switch (state, action) {
            case (.idle, .startEdit):
                state = .editing
            case (.editing, .save):
                state = .saving
            case (.saving, .finish):
                state = .completed
            case (_, .fail(let message)):
                state = .error(message)
            }
        }
    }

    func handle(_ action: TaskAction) {
        switch action {
        case .save(let title):
            machine.send(.save(title))
            Task { await useCase.saveTask(title) }
        default:
            machine.send(action)
        }
    }
}
```

- `ObservationDrivenStateMachine` はサブクラス化せず、Reducer (状態遷移ルール) をクロージャで渡してインスタンス化します。
- 状態更新は `dispatch(_:)` / `send(_:)` を通じて行い、副作用は Reducer ではなく UseCase に委譲します。
- `canSend` を定義すると、UI は「今この入力を送ってよいか」を `disabled` やナビゲーション制御にそのまま使えます。

## 3. UseCase で副作用を扱う

```swift
@Observable
final class TaskUseCase {
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    func saveTask(_ title: String) async {
        do {
            try await repository.save(Task(title: title))
        } catch {
            print("Save error: \(error)")
        }
    }
}
```

- UseCase は副作用やリポジトリ操作を一手に引き受け、テストしやすい構造を保ちます。
- 失敗時のエラー処理やリトライなどもここでカプセル化します。

## 4. View で状態を監視しイベントを送出する

```swift
struct TaskView: View {
    @Bindable var machine: ObservationDrivenStateMachine<TaskState, TaskAction>
    let handle: (TaskAction) -> Void
    @State private var newTitle = ""

    var body: some View {
        let viewState = machine.project {
            TaskViewState(
                state: $0,
                canSave: machine.canSend(.save(newTitle))
            )
        }

        switch viewState.rendering {
        case .idle:
            VStack {
                TextField("Title", text: $newTitle)
                Button("Save") { handle(.save(newTitle)) }
                    .disabled(!viewState.canSave)
            }

        case .saving:
            ProgressView("Saving...")

        case .completed:
            Text("✅ Task Saved")

        case .error(let message):
            Text("❌ \(message)").foregroundStyle(.red)

        case .editing:
            Text("Editing...")
        }
    }
}

struct TaskViewState {
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

- `@Bindable` で StateMachine を監視し、`switch` 文で全状態を描画します。
- `machine.project { ... }` で UI 向け projection を作ると、ドメイン状態に表示都合のフラグや文言を混ぜずに済みます。
- ボタン操作などのユーザーイベントから `TaskStateMachine.handle(_:)` を呼び出し、副作用と状態遷移を用途に応じて組み合わせます。

```swift
let machine = TaskStateMachine(useCase: .init(repository: TaskRepositoryImpl()))
TaskView(
    machine: machine.machine,
    handle: { machine.handle($0) }
)
```

- View には `ObservationDrivenStateMachine` を `@Bindable` で渡しつつ、イベントハンドラとして `TaskStateMachine` のメソッドを共有します。
- 画面ごとの派生情報は `TaskViewState` のような projection に閉じ込め、`machine.canSend(_:)` で操作可能性を判断します。

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

これらの手順をベースに、ドメイン固有の状態・Action・副作用を組み合わせることで、状態駆動なアプリケーションを段階的に構築できます。
