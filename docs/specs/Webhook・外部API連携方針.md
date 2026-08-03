# Webhook・外部API連携方針

## 目的

文書公開、文書更新、インポート結果、レビュー承認、Q&A投稿/回答などの主要イベントを外部システムへ通知できるようにする。

## 設計方針

- 管理画面の `Webhook` から `WebhookEndpoint` を登録する。
- `NotificationEventPublisher` → `WebhookDeliveryDispatcher` で購読中の endpoint へ JSON を POST する。
- 送信先ごとに `WebhookDelivery` を作成し、HTTP status・response body を保存する。
- 初期実装では自動再送キューは持たず、失敗履歴をもとに個別運用で再送要否を判断する。
- 将来、自動再送を追加する場合は、重複送信に備えて受信側が `X-Docs-Portal-Delivery` を冪等キーとして扱える設計を維持する。

## API 仕様

Webhook 設定項目、通知対象イベント一覧、署名方式、送信ヘッダー、payload 例の詳細は [docs-src/api-specification.md](../../docs-src/api-specification.md) の「Webhook 通知」セクションを参照。

外部フォルダ同期の変更通知受信（Google Drive / SharePoint webhook）の仕様は [docs-src/external-folder-sync-webhooks.md](../../docs-src/external-folder-sync-webhooks.md) を参照。
