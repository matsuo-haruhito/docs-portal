# Webhook・外部API連携方針

## 目的

文書公開、文書更新、インポート結果、レビュー承認、Q&A投稿/回答などの主要イベントを外部システムへ通知できるようにする。

## 設計方針

- 管理画面の `Webhook` から `WebhookEndpoint` を登録する。
- `NotificationEventPublisher` → `WebhookDeliveryDispatcher` で購読中の endpoint へ JSON を POST する。
- 送信先ごとに `WebhookDelivery` を作成し、HTTP status・response body を保存する。
- 自動再送は、有効な endpoint に紐づく failed delivery のうち、HTTP 5xx または response 未取得の一時障害だけを対象にする。HTTP 4xx は自動再送しない。
- 定期ジョブは対象 delivery を `failed -> retrying` へ token 付きで claim し、HTTP 通信中は DB transaction を保持しない。同じ delivery を同時に claim できる worker は 1 つだけとする。
- `retry_count` は claim 時ではなく、HTTP response または通信例外を token 一致で確定するときだけ増やす。送信前に worker が停止した stale claim は failed へ戻し、retry budget を消費しない。自動再送の上限は確定した 3 回とし、新しい failed delivery を連鎖作成しない。
- HTTP POST が受信側で処理された後、結果確定前に worker が停止した場合は再送が起こり得る。自動再送では同じ `WebhookDelivery.public_id` を `X-Docs-Portal-Delivery` に使い続け、受信側はこの値を永続的な冪等キーとして重複処理を防ぐ。これは at-least-once delivery であり、sender 単独の exactly-once を保証しない。
- 管理画面からの手動再送は、元 delivery を保持したまま新しい `WebhookDelivery` を作る既存契約を維持し、新しい delivery ID を使う。自動再送と履歴の読み方を分ける。
- `READ_ONLY_MAINTENANCE` 中は自動再送の claim、stale claim 回収、HTTP POST を行わず、送信履歴と failure handoff の read-only 確認だけを残す。

## sales-mgt マスタ同期

`sales-mgt` から会社・案件・文書メタデータを受け取る同期は、Webhook 通知とは別の machine-to-machine upsert API として扱う。

- 正本は `sales-mgt` とし、同期方向は `sales-mgt -> docs-portal` の片方向とする
- `docs-portal` は `(source_system, resource_type, external_id)` を外部同一性として保存し、DB の連番 ID を外部契約へ出さない
- request ごとの `Idempotency-Key` と request digest を受領台帳へ保存する。同じ key / 同じ digest は保存済み response を返し、同じ key / 異なる digest は `409 Conflict` とする
- `source_updated_at` が現在保存済みの source version より古い request は成功扱いの stale no-op とし、後着した古いイベントで状態を巻き戻さない
- 対応する `resource_type` は `company` / `project` / `document` だけとし、未対応値は receipt や mapping を作る前に `422 Unprocessable Content` で拒否する
- 外部 mapping は `company -> Company`、`project -> Project`、`document -> Document` の対応をDB check constraintでも固定し、application validationや管理画面表示だけに依存しない。未紐付けmappingはtarget type / IDをともにNULLにする
- `upsert` は会社、案件、文書メタデータを作成または更新する。`archive` は無効化または archive とし、物理削除しない
- 会社に実ドメインがない場合は、外部 ID 由来の `.invalid` domain を安定生成する。実ドメインが payload で供給された場合だけ置き換える
- 案件は会社の外部 ID を任意で参照できる。文書は案件の外部 ID を必須とし、初期契約では metadata と portal URL を同期対象にする。ファイル実体は既存 import / file upload の dry-run 契約を使い、JSON master sync に base64 で埋め込まない
- machine token は import token と分離した `DOCS_PORTAL_SYNC_TOKEN` を使う。`READ_ONLY_MAINTENANCE` 中は参照済み receipt の冪等応答を除き、新しい upsert / archive を `503` で停止する

送信側は transactional outbox を使い、業務 transaction 内では HTTP を呼ばない。timeout 時の再送、queue 投入欠落、定期 reconciliation により at-least-once delivery を許容し、上記の冪等契約で重複更新を吸収する。

## API 仕様

Webhook 設定項目、通知対象イベント一覧、署名方式、送信ヘッダー、payload 例の詳細は [docs-src/api-specification.md](../../docs-src/api-specification.md) の「Webhook 通知」セクションを参照。

外部フォルダ同期の変更通知受信（Google Drive / SharePoint webhook）の仕様は [docs-src/external-folder-sync-webhooks.md](../../docs-src/external-folder-sync-webhooks.md) を参照。
