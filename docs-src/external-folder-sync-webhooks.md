---
slug: /external-folder-sync-webhooks
---

# 外部フォルダ同期 Webhook 受信仕様

外部フォルダ同期では、Google Drive や SharePoint / OneDrive 側の変更通知を webhook で受け取り、該当する同期元の同期ジョブを起動します。
ポーリングではなく、外部ストレージ側の通知を同期のきっかけにするための共通基盤です。

## 共通パイプライン

```text
Google Drive / SharePoint webhook
  ↓
ExternalFolderSyncWebhooksController
  ↓
ExternalFolderSyncWebhookEvent 保存
  ↓
ExternalFolderSyncWebhookEventJob
  ↓
ExternalFolderSyncJob
  ↓
ExternalFolderSync::Runner
```

Webhook payload だけで完全同期するのではなく、通知を受けたら既存の同期処理を起動します。
同期処理側では `ExternalFolderSyncSource#cursor` や provider 側の delta token を使って差分取得に拡張できます。

## 受信エンドポイント

### Google Drive

```http
POST /external_folder_sync_webhooks/google_drive
```

Google Drive の push notification を受け取ります。
受信時は Google の通知ヘッダーを保存し、`X-Goog-Channel-ID` または `X-Goog-Resource-ID` から有効な `ExternalFolderSyncSubscription` を特定します。

主に利用するヘッダー:

| ヘッダー | 内容 |
| --- | --- |
| `X-Goog-Channel-ID` | watch 登録時の channel ID |
| `X-Goog-Resource-ID` | Google 側 resource ID |
| `X-Goog-Resource-State` | `sync`, `change` などの状態 |
| `X-Goog-Message-Number` | 通知番号 |

### SharePoint / OneDrive

```http
POST /external_folder_sync_webhooks/sharepoint
GET /external_folder_sync_webhooks/sharepoint?validationToken=...
```

Microsoft Graph subscription の通知を受け取ります。
Graph の subscription 作成時に送られる `validationToken` は、plain text でそのまま返します。
通常通知では payload の `value[]` を1件ずつ `ExternalFolderSyncWebhookEvent` として保存します。

主に利用する payload:

| 項目 | 内容 |
| --- | --- |
| `subscriptionId` | Graph subscription ID |
| `resource` | 変更された Graph resource |
| `changeType` | `updated`, `created`, `deleted` など |
| `clientState` | subscription 作成時に設定した検証用値 |

## DBモデル

### `ExternalFolderSyncSubscription`

Provider 側の watch / subscription を管理します。

| 項目 | 内容 |
| --- | --- |
| `external_folder_sync_source_id` | 対象の外部フォルダ同期元 |
| `provider` | `google_drive` / `sharepoint` |
| `status` | `pending` / `active` / `expired` / `failed` / `disabled` |
| `provider_subscription_id` | SharePoint / Graph subscription ID |
| `provider_channel_id` | Google Drive channel ID |
| `provider_resource_id` | Google Drive resource ID |
| `callback_url` | Provider に登録した callback URL |
| `verification_token_digest` | channel token / clientState などの検証値 digest |
| `expires_at` | subscription 有効期限 |
| `last_renewed_at` | 最終更新日時 |
| `provider_metadata` | Provider 固有の補足情報 |

### `ExternalFolderSyncWebhookEvent`

受信した webhook を保存します。

| 項目 | 内容 |
| --- | --- |
| `external_folder_sync_source_id` | 特定できた同期元 |
| `external_folder_sync_subscription_id` | 特定できた subscription |
| `provider` | `google_drive` / `sharepoint` |
| `status` | `received` / `enqueued` / `ignored` / `failed` |
| `event_key` | 冪等性キー |
| `received_at` | 受信日時 |
| `headers_json` | 必要な通知ヘッダー |
| `payload_json` | 通知 payload |
| `error_message` | 無視・失敗理由 |

## 冪等性

`external_folder_sync_webhook_events` は `provider + event_key` で一意にします。
同じ通知が再送されても、同じ event_key なら重複保存せず、二重 enqueue を避けます。

Google Drive の event key は主に次の値から作ります。

```text
X-Goog-Channel-ID:X-Goog-Resource-ID:X-Goog-Resource-State:X-Goog-Message-Number
```

SharePoint の event key は主に次の値から作ります。

```text
subscriptionId:resource:changeType:clientState:sequenceNumber
```

## 現時点で実装済みの範囲

- webhook 受信 endpoint
- Google Drive / SharePoint 通知の受信記録
- SharePoint validationToken 応答
- subscription / event 保存テーブル
- 受信 event から既存 `ExternalFolderSyncJob` を enqueue
- Model Browser で subscription / event を確認できるモデル定義

## 次段階で実装する範囲

### Google Drive

- `changes.watch` による watch 登録
- `channels.stop` による watch 停止
- channel 有効期限前の再登録
- `changes.list` による `cursor` 以降の差分取得
- `X-Goog-Channel-Token` の検証

### SharePoint / OneDrive

- Microsoft Graph `subscriptions` 作成
- subscription 更新 / 削除
- 有効期限前の renewal job
- delta query による差分取得
- `clientState` の検証

## 運用上の注意

- Provider から到達できる公開 HTTPS URL が必要です。
- webhook は「同期開始のきっかけ」として扱い、実データ取得は provider API で行います。
- 通知は重複・遅延・欠落し得るため、event_key の冪等性と full scan fallback を残します。
- subscription は期限切れになるため、定期 renewal job が必要です。
- Google Drive / SharePoint とも、初回通知や validation 通知は実変更ではない場合があります。

## 関連管理画面

- 連携メニュー: 外部フォルダ同期
- 連携メニュー: API仕様
- 管理メニュー: モデルブラウザ
