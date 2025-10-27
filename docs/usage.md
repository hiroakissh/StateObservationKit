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
final class TaskStateMachine: ObservationDrivenStateMachine<TaskState, TaskEvent> {
    private let useCase: TaskUseCase

    init(useCase: TaskUseCase) {
        self.useCase = useCase
        super.init(initial: .idle) { state, event in
            switch (state, event) {
            case (.idle, .startEdit):
                .editing
            case (.editing, .save):
                .saving
            case (.saving, .finish):
                .completed
            case (_, .fail(let message)):
                .error(message)
            }
        }
    }

    func handle(_ event: TaskEvent) async {
        switch event {
        case .save(let title):
            await send(.save(title))
            await useCase.saveTask(title)
        default:
            await send(event)
        }
    }
}
```

- `ObservationDrivenStateMachine` を継承し、初期状態と Reducer (状態遷移ルール) を指定します。
- 状態更新は `send(_:)` を通じて行い、外部副作用は UseCase に委譲します。

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
    @Bindable var machine: TaskStateMachine
    @State private var newTitle = ""

    var body: some View {
        switch machine.state {
        case .idle:
            VStack {
                TextField("Title", text: $newTitle)
                Button("Save") {
                    Task { await machine.handle(.save(newTitle)) }
                }
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
- ボタン操作などのユーザーイベントから StateMachine の `handle(_:)` を呼び出し、副作用を含む遷移を制御します。

これらの手順をベースに、ドメイン固有の状態・イベント・副作用を組み合わせることで、状態駆動なアプリケーションを段階的に構築できます。
