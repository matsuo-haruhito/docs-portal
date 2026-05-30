# Webhook設定・送信失敗確認runbook

## 目的

`Webhook` 管理画面で外部通知の送信先を登録し、送信履歴から失敗原因の切り分けと手動再送を始めるための runbook です。payload や署名ヘッダーの設計方針は [Webhook・外部API連携方針](./Webhook・外部API連携方針.md) を正本にし、この runbook では日常運用で見る画面と確認順に絞ります。

## 入口

- internal admin で `admin/webhook_endpoints` の `Webhook` 画面を開きます。
- 画面には `新規登録`、`Webhook設定`、`最近の送信履歴` が並びます。
- 送信履歴は `WebhookDelivery.recent.limit(50)` の範囲で、選択した表示条件ごとに最大 50 件を新しい順に確認します。
- 画面には `表示範囲: ...  N件中M件を表示しています` が出るため、status filter 後の総件数と表示件数を分けて確認します。
- 送信履歴は `すべて` / `送信待ち` / `成功` / `失敗` で表示を絞り込めます。
- `失敗` 表示中のまとめて再送は、表示中の最大 50 件のうち failed かつ endpoint が有効な delivery だけを対象にします。
- 50 件外の履歴まで探す必要がある場合は、この画面だけで判断せず、endpoint / event type / 日付などの追加条件を決める後続 slice として扱います。

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

`WebhookDelivery` には request body、response body、error message、sent_at も保存されます。ただし detail 画面でも request body は first slice では非表示です。secret や個人情報を含みうるため、request body の全表示が必要な場合は表示範囲とマスキング方針を別途確認してください。

## 失敗時の確認順

1. `Webhook設定` で endpoint が `有効` になっているか、対象 event type が選ばれているかを確認します。
2. `送信履歴` を `失敗` に絞り込み、表示範囲の総件数と表示件数を確認します。50 件外まで調べる必要がある場合は、この画面だけで網羅確認したと判断しないでください。
3. `送信先URL` が現在の受信先 URL と一致しているか、受信先側で route / token / IP allowlist などが変わっていないかを確認します。
4. `HTTP` が 4xx の場合は、受信先の認証・署名検証・payload validation を先に見ます。
5. `HTTP` が 5xx の場合は、受信先サービスの障害・timeout・一時的な処理失敗を先に見ます。
6. `エラー` に timeout や接続例外が出ている場合は、ネットワーク疎通、DNS、TLS、受信先の稼働状態を確認します。
7. `mail / webhook の継続失敗` として監視側で拾われている場合は、[監視・アラート設計](./監視・アラート設計.md) の外部依存確認と合わせて見ます。

## 手動再送の扱い

current 実装では、失敗した delivery だけを管理画面から 1 件ずつ、または `失敗` 表示中の表示範囲のうち再送可能な delivery だけをまとめて手動再送できます。まとめて再送の対象は failed かつ endpoint が有効な delivery に限定され、停止中 endpoint、成功済み、送信待ちの delivery は対象外です。自動 retry queue、scheduled retry、指数 backoff、retry metadata、親子 delivery relation はまだありません。

手動再送するときは次を確認します。

1. 送信履歴を `失敗` に絞り込み、対象 delivery の endpoint と event type を確認します。
2. まとめて再送を使う場合は、画面に表示される対象件数、endpoint、event type の内訳を確認します。
3. 受信先側で同じ event を再処理しても問題ないかを確認します。受信側は `X-Docs-Portal-Delivery` などの delivery identifier を冪等キーとして扱えるようにしておくのが安全です。
4. 対象行に `再送` ボタンが出ていること、または `失敗` 表示中に `表示中の失敗Webhookをまとめて再送` ボタンが出ていることを確認します。failed ではない delivery、または停止中 endpoint の delivery は再送できません。
5. 確認ダイアログで、現在の Webhook 設定を使って再送することと、受信先側の重複処理に注意することを確認して実行します。
6. 再送結果は元 delivery を上書きせず、新しい `WebhookDelivery` として送信履歴に残ります。実行後は送信履歴の新しい行で status / HTTP / error を確認します。

再送できない delivery を無理に再送するためにコードやデータを直接操作する必要がある場合は、この runbook だけで判断せず、対象 event、受信先の冪等性、重複送信時の扱いを人間確認に回してください。

## 関連 docs

- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md)
- [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
