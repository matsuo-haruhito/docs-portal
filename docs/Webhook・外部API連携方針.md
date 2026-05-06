# Webhook・外部API連携方針

## 目的

文書公開、文書更新、インポート結果、レビュー承認、Q&A投稿/回答などの主要イベントを外部システムへ通知できるようにする。

## 設定

- 管理画面の `Webhook` から `WebhookEndpoint` を登録する。
- endpoint は名称、送信先URL、有効/停止、通知対象イベント、署名シークレットを持つ。
- 通知対象イベントは `WebhookEndpoint::EVENT_TYPES` で管理する。
- 初期対象イベントは次のとおり。
  - `document_updated`
  - `document_published`
  - `import_completed`
  - `import_failed`
  - `review_approved`
  - `qa_posted`
  - `qa_answered`

## 送信

- `NotificationEventPublisher` が `NotificationEvent` を作成した後、購読中の active endpoint へ `WebhookDeliveryDispatcher` が JSON を POST する。
- payload にはイベント ID、イベント種別、発生時刻、タイトル、本文、案件、文書、版、実行者の公開識別子を含める。
- 送信先ごとに `WebhookDelivery` を作成し、送信先URL、request body、HTTP status、response body、エラー、送信時刻を保存する。
- 2xx 応答は `succeeded`、それ以外または例外は `failed` として記録する。

## 認証・署名

- endpoint に署名シークレットが設定されている場合、request body を HMAC-SHA256 で署名する。
- 署名は `X-Docs-Portal-Signature-256: sha256=<hex digest>` として送信する。
- イベント種別は `X-Docs-Portal-Event`、配信識別子は `X-Docs-Portal-Delivery` で送信する。
- 送信先は HTTPS を推奨し、secret token は外部へ表示・共有しない前提で管理する。

## 送信履歴と再送

- 管理画面の `Webhook` では最近の送信履歴を確認できる。
- 初期実装では自動再送キューは持たず、失敗履歴をもとに個別運用で再送要否を判断する。
- 将来、自動再送を追加する場合は、重複送信に備えて受信側が `X-Docs-Portal-Delivery` を冪等キーとして扱える設計を維持する。
