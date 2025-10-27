# アーキテクチャと責務分離

StateObservationKit は、状態を中心に据えたアプリケーション構造を推奨します。以下の依存方向を守ることで、ビューとデータソース間の結合度を最小化し、状態遷移の見通しを高めます。

```
View
 └─→ StateMachine (状態遷移とロジック制御)
       └─→ UseCase (副作用・Repository 操作)
             └─→ Repository / API / Cache
```

## 各レイヤーの責務

| 層 | 役割 | 主な要素 |
| --- | --- | --- |
| StateMachine | 状態・イベントの定義、フロー制御 | `ObservationDrivenStateMachine` / `TransitionDrivenStateMachine` |
| UseCase | データ操作・API 呼び出し・キャッシュ切替 | Repository 呼び出し、非同期副作用の管理 |
| Repository | 永続化・外部通信・I/O | SwiftData, URLSession, CoreData など |
| View | 状態の描画とイベント発火 | `@Bindable` / `switch` による網羅的 UI |

### StateMachine — アプリの「司令塔」
- 状態とイベントを型安全に定義し、状態遷移の整合性を保証します。
- Reducer で状態遷移のルールを宣言し、副作用の実行は UseCase に委譲します。
- `dispatch(_:)` のみを通じて状態を更新し、直接 `state` を書き換えないことで監視とテストを容易にします。

### UseCase — 実行部隊
- Repository や API などの副作用を抽象化し、StateMachine からの指示を受けて実際の処理を行います。
- 非同期処理やエラーハンドリングを担当し、完了結果を状態遷移イベントとして StateMachine に返します。

### Repository / DataSource — 境界レイヤー
- I/O、永続化、ネットワーク通信などの具体的な実装を担当します。
- UseCase からの依頼を受け、必要なデータを取得・保存します。

### View — 状態を映す鏡
- `@Bindable` で StateMachine を監視し、状態に応じた UI をレンダリングします。
- `switch` による網羅的な分岐で状態を描画し、イベントを発火させて StateMachine に返します。

## 依存関係の維持
- View は StateMachine の公開インターフェースのみに依存し、UseCase や Repository へ直接アクセスしません。
- UseCase はプロトコルで抽象化された Repository に依存し、テスト時はモックを注入できるようにします。
- StateMachine はアプリケーション層の中心として、副作用を伴わないロジックを集中管理します。

この構造を採用することで、Swift Concurrency と Observation の恩恵を最大限に活かしつつ、クリーンでテスタブルなコードベースを維持できます。
