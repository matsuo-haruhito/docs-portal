# Google Drive外部フォルダ同期

## 目的

Google Driveフォルダを外部文書置き場として登録し、docs-portalへ片方向で取り込むための仕様です。

この文書は、外部フォルダ同期の current support のうち、実際に `dry_run` / `apply` / `同期ジョブ登録` / `変更通知` まで進められる Google Drive レーンを正本としてまとめたものです。

一方で current `main` の管理画面と model では、`ExternalFolderSyncSource` に `microsoft_graph` provider を保存し、SharePoint / OneDrive の共有 URL から `drive_id` / `folder_item_id` / `folder_path` / `site_id` を metadata として保持する first slice も入っています。この文書では、その provider-aware な current state と矛盾しないように「Google Drive で今どこまで同期できるか」を中心に整理します。

preview 用の `MicrosoftGraphConnection` との役割分担や、Google Drive OAuth / preview folder をどこで使うかは [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) を参照してください。日常運用で一覧・詳細のどこを見るかは [外部フォルダ同期dry-run・apply運用 runbook](./外部フォルダ同期dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md) を参照してください。

## この文書の範囲

- Google Drive を同期元にした `external_to_portal` の取り込み運用
- Google Drive の `service_account` / `oauth_user` 認証
- Google Drive source に対する `dry_run` / `apply` / `enqueue` / 変更通知
- SharePoint / OneDrive の metadata-only source が同じ管理画面に並ぶ current state との境界整理

この文書の対象外:

- Portal から Google Drive への反映
- 双方向同期
- Google Drive 側削除の portal 側物理削除
- Webhook / push notification の一般化
- Google Drive changes API を使った厳密な差分同期
- SharePoint / OneDrive source の保存手順や metadata 確認の詳細説明
  - これらは current `main` で一部対応済みですが、正本は [外部フォルダ同期dry-run・apply運用 runbook](./外部フォルダ同期dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md) と [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) に置きます

## current support の読み方

| provider / lane | 保存 | metadata 確認 | `dry_run` / `apply` / `enqueue` | 変更通知 |
| --- | --- | --- | --- | --- |
| `google_drive` | 対応済み | 対応済み | 対応済み | 対応済み |
| `microsoft_graph` (SharePoint / OneDrive) | 対応済み | 対応済み | 未対応 | 未対応 |

ここでいう `microsoft_graph` は、Google Drive と同じ同期本体がもう使える、という意味ではありません。current `main` で安全に言えるのは「共有 URL から同期元 metadata を保存し、詳細画面で確認できる」段階までです。

## 対象

- provider-aware な管理画面には `google_drive` と `microsoft_graph` があるが、この文書で同期本体を扱うのは `google_drive` のみ
- Google Drive の current 同期方向は `external_to_portal` のみ
- Google Drive の current 競合方針は `manual` のみ
- Google Drive の認証方式は `service_account` または `oauth_user`
- 管理画面から `dry-run` / `同期実行` / `同期ジョブ登録` を行う
- rake task から全 source または個別 source を同期できる
- Google Drive 側削除は portal 側から物理削除せず、`delete_detected` として記録する
- Google Docs / Sheets / Slides / Drawings は Office 形式または PDF へ export して取り込む

## 認証

### Service Account

Google Cloud の Service Account JSON を管理画面へ登録します。

運用時は、同期対象の Google Drive フォルダを Service Account のメールアドレスへ共有してください。

登録した認証設定は `ExternalFolderSyncSource.auth_config` に暗号化保存します。

### OAuth user

OAuth user 方式では、管理画面で同期 source を保存した後、詳細画面の「Google OAuth接続」から Google 認可を行います。

OAuth user 方式では、次の環境変数が必要です。

```bash
GOOGLE_DRIVE_OAUTH_CLIENT_ID=...
GOOGLE_DRIVE_OAUTH_CLIENT_SECRET=...
```

Google Cloud Console 側の OAuth redirect URI には、次の管理画面 callback URL を登録してください。

```text
https://<host>/admin/external_folder_sync_oauth_connections/callback
```

OAuth user 方式では、認可した Google ユーザーが閲覧できる Drive フォルダを同期対象にします。Service Account へのフォルダ共有は不要です。

取得した refresh token は `ExternalFolderSyncSource.auth_config` に暗号化保存し、同期時に access token へ更新します。

## 主なモデル

### ExternalFolderSyncSource

外部フォルダ同期元の設定です。

- `project`
- `provider`
- `auth_type`
- `name`
- `folder_url`
- `external_folder_id`
- `external_folder_path`
- `sync_direction`
- `conflict_policy`
- `enabled`
- `auth_config`
- `cursor`
- `last_synced_at`
- `last_error_message`

current `main` では `provider` に `google_drive` と `microsoft_graph` があり、`auth_type` も Google Drive 用の `service_account` / `oauth_user` に加えて、Graph metadata 保存用の `microsoft_graph_connection` を持ちます。

ただし、同期本体として `dry_run` / `apply` / `enqueue` / 変更通知まで current support があるのは Google Drive source です。`microsoft_graph` source は保存済み metadata の確認までを安全な読み方としてください。

`cursor` には、Google Drive 同期成功後に changes API 用の start page token を保存します。現時点では次回同期の厳密な差分取得には使わず、後続実装のための境界情報として保持します。

### ExternalFolderSyncRun

同期実行の履歴です。

- `source`
- `status`
- `mode`: `dry_run` / `apply`
- `started_at` / `finished_at`
- `scanned` / `created` / `updated` / `skipped` / `deleted` / `errors` の件数
- `result_json`
- `summary_json`

current docs の範囲では、この run は Google Drive source に対して読むのが正本です。SharePoint / OneDrive source は metadata 保存 first slice のため、この run を前提にした運用へはまだ進めません。

### ExternalFolderSyncItem

Google Drive item と portal 側 Document / DocumentVersion / DocumentFile の対応関係です。

- `source`
- `external_item_id`
- `path`
- `name`
- `mime_type`
- `size`
- `checksum`
- `external_modified_at`
- `portal_modified_at`
- `sync_status`
- `provider_metadata`

Google ネイティブ形式を export した場合、`provider_metadata` に元の path / name / mime type と export 先 mime type を保持します。

## dry-run / apply

`dry-run` は Google Drive を列挙し、以下の予定を `ExternalFolderSyncRun.result_json` に保存します。

- `create`: portal 側に未取り込み
- `update`: 既存取り込み済みだが checksum / modified_at / path が変化
- `skip`: 変更なし
- `delete_detected`: Drive 側で見えなくなった既存 item。dry-run では DB 状態を変更しない
- `error`: export 非対応の Google ネイティブ形式など

`apply` は `create` / `update` を portal 側へ取り込み、Document / DocumentVersion / DocumentFile を作成します。

Google Drive 側で見えなくなった既存 item は `delete_detected` として記録し、portal 側 Document / DocumentFile は保持します。

## Google ネイティブ形式の export

以下の Google ネイティブ形式を export して取り込みます。

- Google Docs: `.docx`
- Google Sheets: `.xlsx`
- Google Slides: `.pptx`
- Google Drawings: `.pdf`

export 非対応の Google ネイティブ形式は `error` として記録します。

## 定期実行

ActiveJob の入口として `ExternalFolderSyncJob` を用意しています。

管理画面の「同期ジョブ登録」から 1 source の同期 job を登録できます。

rake task でも同期できます。

```bash
bin/rails external_folder_sync:sync_all
bin/rails external_folder_sync:enqueue_all
bin/rails 'external_folder_sync:sync[efs_xxx]'
```

実際の定期実行は cron / scheduler / queue adapter の設定に合わせて `external_folder_sync:enqueue_all` または `sync_all` を呼び出してください。

## 関連する current support の境界

- `MicrosoftGraphConnection` は Office preview 用の接続であり、外部フォルダ同期元そのものではありません
- SharePoint / OneDrive source を保存するときは、案件ごとの有効な `MicrosoftGraphConnection` が前提です
- SharePoint / OneDrive source では current `main` でも `drive_id` / `folder_item_id` / `folder_path` / `site_id` の保存確認までを扱い、同期本体は後続 issue の範囲に留めます
- provider-aware な画面説明や初回登録導線は runbook 側で更新されることがあるため、日常運用の入口判断は [外部フォルダ同期dry-run・apply運用 runbook](./外部フォルダ同期dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md) を優先してください

## 今後の拡張候補

- Google Drive changes API による厳密な差分同期
- Portal -> Google Drive publish
- `microsoft_graph` provider に Google Drive と同等の `dry_run` / `apply` / `enqueue` / 変更通知を拡張する
- provider adapter として Box を追加する
- conflict 解消 UI
