# 利用方法

StateObservationKit を使って状態駆動アプリを構築するための基本的な流れを紹介します。ここではタスク管理ドメインを例に、状態とイベントの定義から View での利用までを順に説明します。

## 1. 状態とイベントを定義する

```swift
enum TaskState: StateType {
    case idle
    case editing
    case saving
    case completed
    case error(String)
}

enum TaskEvent: EventType {
    case startEdit
    case save(String)
    case finish
    case fail(String)
}
```

- `StateType` と `EventType` に準拠した `enum` を定義することで、遷移可能な状態とイベントを列挙します。
- エラーやコンテキスト付きの情報は、関連値を活用して表現します。

## 2. StateMachine を定義する

```swift
@MainActor
final class TaskStateMachine {
    let machine: ObservationDrivenStateMachine<TaskState, TaskEvent>
    private let useCase: TaskUseCase

    init(useCase: TaskUseCase) {
        self.useCase = useCase
        self.machine = ObservationDrivenStateMachine(initial: .idle) { state, event in
            switch (state, event) {
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

    func handle(_ event: TaskEvent) {
        switch event {
        case .save(let title):
            machine.dispatch(.save(title))
            Task { await useCase.saveTask(title) }
        default:
            machine.dispatch(event)
        }
    }
}
```

- `ObservationDrivenStateMachine` はサブクラス化せず、Reducer (状態遷移ルール) をクロージャで渡してインスタンス化します。
- 状態更新は `dispatch(_:)` を通じて行い、副作用は Reducer ではなく UseCase に委譲します。

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
    @Bindable var machine: ObservationDrivenStateMachine<TaskState, TaskEvent>
    let handle: (TaskEvent) -> Void
    @State private var newTitle = ""

    var body: some View {
        switch machine.state {
        case .idle:
            VStack {
                TextField("Title", text: $newTitle)
                Button("Save") { handle(.save(newTitle)) }
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
```

- `@Bindable` で StateMachine を監視し、`switch` 文で全状態を描画します。
- ボタン操作などのユーザーイベントから `TaskStateMachine.handle(_:)` を呼び出し、副作用と状態遷移を用途に応じて組み合わせます。

```swift
let machine = TaskStateMachine(useCase: .init(repository: TaskRepositoryImpl()))
TaskView(
    machine: machine.machine,
    handle: { machine.handle($0) }
)
```

- View には `ObservationDrivenStateMachine` を `@Bindable` で渡しつつ、イベントハンドラとして `TaskStateMachine` のメソッドを共有します。

これらの手順をベースに、ドメイン固有の状態・イベント・副作用を組み合わせることで、状態駆動なアプリケーションを段階的に構築できます。
