# Webhook設定・送信失敗確認runbook

## 目的

`Webhook` 管理画面で外部通知の送信先を登録し、送信履歴から失敗原因の切り分けと手動再送を始めるための runbook です。payload や署名ヘッダーの設計方針は [Webhook・外部API連携方針](./Webhook・外部API連携方針.md) を正本にし、この runbook では日常運用で見る画面と確認順に絞ります。

## 入口

- internal admin で `admin/webhook_endpoints` の `Webhook` 画面を開きます。
- 画面には `新規登録`、`Webhook設定`、`最近の送信履歴` が並びます。
- `Webhook設定` と `最近の送信履歴` には表示設定があります。失敗調査では送信履歴側の `ステータス`、`HTTP`、`エラー`、`操作` を残しておくと、filter 後の詳細確認と再送可否を読み違えにくくなります。
- 送信履歴は `WebhookDelivery.recent.limit(50)` の範囲で、選択した表示条件ごとに最大 50 件を新しい順に確認します。
- 画面には `表示範囲: ...  N件中M件を表示しています` が出るため、status filter 後の総件数と表示件数を分けて確認します。
- 送信履歴は `すべて` / `送信待ち` / `成功` / `失敗` で表示を絞り込めます。
- 50 件外の履歴や、特定 endpoint / event type / status / 作成日の履歴を探す場合は `送信履歴検索へ` から `admin/webhook_deliveries` を開きます。
- 送信履歴検索は最大 100 件までの read-only 検索一覧です。検索結果全体への bulk retry はありません。
- 送信履歴の `詳細` と行ごとの `再送` は、現在の status filter または送信履歴検索の条件を安全な戻り先として引き継ぎます。`失敗` 表示や検索一覧から詳細へ入った場合、戻り先と 1 件再送後の戻り先は元の一覧です。
- 不正な戻り先 filter や任意 URL は引き継がず、通常の Webhook 一覧へ戻します。検索一覧の戻り先は `endpoint`、`event_type`、`status`、`created_from`、`created_to` の許可済み条件だけを組み立てます。
- `失敗` 表示中のまとめて再送は、表示中の最大 50 件のうち failed かつ endpoint が有効な delivery だけを対象にします。送信履歴検索の 100 件一覧は bulk retry 対象ではありません。

## 新規登録・編集で見る項目

- `名称`: 送信先を識別する運用名です。
- `送信先URL`: `http` / `https` の URL が必須です。外部送信では HTTPS を標準にしてください。
- `署名シークレット`: 入力すると送信時に `X-Docs-Portal-Signature-256: sha256=<hex digest>` が付与されます。受信側で request body の HMAC-SHA256 検証に使います。
- `有効`: off の endpoint は `WebhookEndpoint.subscribed_to` の対象外になり、送信されません。失敗 delivery の手動再送も、endpoint が停止中なら実行できません。
- `通知対象イベント`: endpoint ごとに購読する event type を選びます。保存時に未対応値は validation error になります。

current `WebhookEndpoint::EVENT_TYPES` は次の 7 種類です。

- `document_updated`
- `document_published`
- `import_completed`
- `import_failed`
- `review_approved`
- `qa_posted`
- `qa_answered`

## 送信履歴で見る項目

`最近の送信履歴` では、外部通知の成否を endpoint と event type 単位で確認します。

- `作成日時`: delivery record が作成された時刻です。
- `設定`: 対象の Webhook 設定名です。
- `イベント`: delivery の `event_type` です。
- `ステータス`: `送信待ち` / `成功` / `失敗` を表示します。
- `HTTP`: 受信先から返った HTTP status です。通信例外など response がない失敗では空になります。
- `エラー`: 例外時の error message です。HTTP non-2xx の場合は `HTTP` と保存済み response body を手掛かりにします。
- `操作`: `詳細` から delivery の response body / sent_at / target URL などを確認できます。failed かつ endpoint が有効な delivery には `再送` ボタンも表示されます。それ以外は `再送不可` と表示されます。

送信履歴の表示設定を絞る場合も、状態確認では `ステータス` と `操作`、失敗調査では `HTTP` と `エラー` を残してください。`詳細` へ入ったあとの戻り先は status filter または送信履歴検索の許可済み条件だけを保持するため、表示設定で列を隠しても delivery の詳細情報や再送条件そのものは変わりません。

`WebhookDelivery` には request body、response body、error message、sent_at も保存されます。ただし detail 画面でも request body は first slice では非表示です。secret や個人情報を含みうるため、request body の全表示が必要な場合は表示範囲とマスキング方針を別途確認してください。

## 送信履歴検索の使い分け

`admin/webhook_deliveries` の送信履歴検索は、最近 50 件の一覧だけでは見つけにくい delivery を探すための補助入口です。

使える条件:

- `Webhook設定`: endpoint 単位で絞り込む
- `イベント`: `WebhookEndpoint::EVENT_TYPES` の event type で絞り込む
- `ステータス`: `送信待ち` / `成功` / `失敗` で絞り込む
- `作成日From` / `作成日To`: delivery record の `created_at` 日付範囲で絞り込む

読み方:

- 検索結果は `created_at desc, id desc` の新しい順で最大 100 件まで表示します。
- 100 件を超える場合は、endpoint、event type、status、作成日を足して範囲を狭めます。無制限一覧や任意の表示件数指定は current support ではありません。
- 検索結果から `詳細` に入った場合、`送信履歴検索へ戻る` と 1 件再送後の戻り先は元の検索条件です。
- 送信履歴検索には bulk retry を置きません。まとめて再送は従来どおり `Webhook` 画面の `失敗` 表示中、最近 50 件のうち再送可能な delivery に限定します。
- payload edit、payload replay、自動 retry、retention policy 判断は扱いません。

## 失敗時の確認順

1. `Webhook設定` で endpoint が `有効` になっているか、対象 event type が選ばれているかを確認します。
2. `送信履歴` を `失敗` に絞り込み、表示範囲の総件数と表示件数を確認します。50 件外まで調べる必要がある場合は、`送信履歴検索へ` から endpoint / event type / status / 作成日で探します。
3. 失敗行の `詳細` を開きます。`Webhook一覧へ戻る` または `送信履歴検索へ戻る` は元の一覧へ戻るため、複数件を順に確認する場合も同じ条件から再開できます。
4. `送信先URL` が現在の受信先 URL と一致しているか、受信先側で route / token / IP allowlist などが変わっていないかを確認します。
5. `HTTP` が 4xx の場合は、受信先の認証・署名検証・payload validation を先に見ます。
6. `HTTP` が 5xx の場合は、受信先サービスの障害・timeout・一時的な処理失敗を先に見ます。
7. `エラー` に timeout や接続例外が出ている場合は、ネットワーク疎通、DNS、TLS、受信先の稼働状態を確認します。
8. `mail / webhook の継続失敗` として監視側で拾われている場合は、[監視・アラート設計](./監視・アラート設計.md) の外部依存確認と合わせて見ます。

## 手動再送の扱い

current 実装では、失敗した delivery だけを管理画面から 1 件ずつ、または `失敗` 表示中の表示範囲のうち再送可能な delivery だけをまとめて手動再送できます。まとめて再送の対象は failed かつ endpoint が有効な delivery に限定され、停止中 endpoint、成功済み、送信待ちの delivery は対象外です。自動 retry queue、scheduled retry、指数 backoff、retry metadata、親子 delivery relation はまだありません。

手動再送するときは次を確認します。

1. 送信履歴を `失敗` に絞り込み、対象 delivery の endpoint と event type を確認します。
2. まとめて再送を使う場合は、画面に表示される対象件数、endpoint、event type の内訳を確認します。
3. 受信先側で同じ event を再処理しても問題ないかを確認します。受信側は `X-Docs-Portal-Delivery` などの delivery identifier を冪等キーとして扱えるようにしておくのが安全です。
4. 対象行に `再送` ボタンが出ていること、または `失敗` 表示中に `表示中の失敗Webhookをまとめて再送` ボタンが出ていることを確認します。failed ではない delivery、または停止中 endpoint の delivery は再送できません。
5. 確認ダイアログで、現在の Webhook 設定を使って再送することと、受信先側の重複処理に注意することを確認して実行します。
6. 1 件再送は、詳細画面から実行しても元の status filter 一覧または送信履歴検索一覧へ戻ります。`失敗` 表示や検索一覧から詳細へ入った場合は、再送後も同じ条件で結果確認を再開できます。
7. 再送結果は元 delivery を上書きせず、新しい `WebhookDelivery` として送信履歴に残ります。実行後は送信履歴の新しい行で status / HTTP / error を確認します。

再送できない delivery を無理に再送するためにコードやデータを直接操作する必要がある場合は、この runbook だけで判断せず、対象 event、受信先の冪等性、重複送信時の扱いを人間確認に回してください。

## 関連 docs

- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md)
- [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
