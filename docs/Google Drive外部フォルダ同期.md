# Google Drive外部フォルダ同期

## 目的

Google Driveフォルダを外部文書置き場として登録し、docs-portalへ片方向で取り込むための仕様です。

この機能は Microsoft Graph / SharePoint / OneDrive の双方向同期を実装する前に、外部フォルダ同期の共通モデルとdry-run運用を小さく検証するために追加します。

## 対象

- providerは `google_drive` のみ
- 同期方向は `external_to_portal` のみ
- 競合方針は `manual` のみ
- 認証方式は `service_account` または `oauth_user` を選択できる
- 管理画面から `dry-run` / `同期実行` / `同期ジョブ登録` を行う
- rake taskから全sourceまたは個別sourceを同期できる
- Google Drive側削除はportal側から物理削除せず、`delete_detected` として記録する
- Google Docs / Sheets / Slides / Drawings はOffice形式またはPDFへexportして取り込む

## 対象外

- PortalからGoogle Driveへの反映
- 双方向同期
- Google Drive側削除のportal側物理削除
- Webhook / push notification
- Google Drive changes APIを使った厳密な差分同期

## 認証

### Service Account

Google Cloud のService Account JSONを管理画面へ登録します。

運用時は、同期対象のGoogle DriveフォルダをService Accountのメールアドレスへ共有してください。

登録した認証設定は `ExternalFolderSyncSource.auth_config` に暗号化保存します。

### OAuth user

OAuth user方式では、管理画面で同期sourceを保存した後、詳細画面の「Google OAuth接続」からGoogle認可を行います。

OAuth user方式では、次の環境変数が必要です。

```bash
GOOGLE_DRIVE_OAUTH_CLIENT_ID=...
GOOGLE_DRIVE_OAUTH_CLIENT_SECRET=...
```

Google Cloud Console 側のOAuth redirect URIには、次の管理画面 callback URL を登録してください。

```text
https://<host>/admin/external_folder_sync_oauth_connections/callback
```

OAuth user方式では、認可したGoogleユーザーが閲覧できるDriveフォルダを同期対象にします。Service Accountへのフォルダ共有は不要です。

取得したrefresh tokenは `ExternalFolderSyncSource.auth_config` に暗号化保存し、同期時にaccess tokenへ更新します。

## 主なモデル

### ExternalFolderSyncSource

外部フォルダ同期元の設定です。

- project
- provider
- auth_type
- name
- folder_url
- external_folder_id
- external_folder_path
- sync_direction
- conflict_policy
- enabled
- auth_config
- cursor
- last_synced_at
- last_error_message

`cursor` には、同期成功後にGoogle Drive changes API用のstart page tokenを保存します。現時点では次回同期の厳密な差分取得には使わず、後続実装のための境界情報として保持します。

### ExternalFolderSyncRun

同期実行の履歴です。

- source
- status
- mode: `dry_run` / `apply`
- started_at / finished_at
- scanned / created / updated / skipped / deleted / errors の件数
- result_json
- summary_json

### ExternalFolderSyncItem

Google Drive itemとportal側Document / DocumentVersion / DocumentFileの対応関係です。

- source
- external_item_id
- path
- name
- mime_type
- size
- checksum
- external_modified_at
- portal_modified_at
- sync_status
- provider_metadata

Googleネイティブ形式をexportした場合、`provider_metadata` に元のpath / name / mime typeとexport先mime typeを保持します。

## dry-run / apply

`dry-run` はGoogle Driveを列挙し、以下の予定を `ExternalFolderSyncRun.result_json` に保存します。

- `create`: portal側に未取り込み
- `update`: 既存取り込み済みだがchecksum / modified_at / pathが変化
- `skip`: 変更なし
- `delete_detected`: Drive側で見えなくなった既存item。dry-runではDB状態を変更しない
- `error`: export非対応のGoogleネイティブ形式など

`apply` は `create` / `update` をportal側へ取り込み、Document / DocumentVersion / DocumentFileを作成します。

Google Drive側で見えなくなった既存itemは `delete_detected` として記録し、portal側Document / DocumentFileは保持します。

## Googleネイティブ形式のexport

以下のGoogleネイティブ形式をexportして取り込みます。

- Google Docs: `.docx`
- Google Sheets: `.xlsx`
- Google Slides: `.pptx`
- Google Drawings: `.pdf`

export非対応のGoogleネイティブ形式は `error` として記録します。

## 定期実行

ActiveJobの入口として `ExternalFolderSyncJob` を用意しています。

管理画面の「同期ジョブ登録」から1 sourceの同期jobを登録できます。

rake taskでも同期できます。

```bash
bin/rails external_folder_sync:sync_all
bin/rails external_folder_sync:enqueue_all
bin/rails 'external_folder_sync:sync[efs_xxx]'
```

実際の定期実行はcron / scheduler / queue adapterの設定に合わせて `external_folder_sync:enqueue_all` または `sync_all` を呼び出してください。

## 今後の拡張候補

- Google Drive changes APIによる厳密な差分同期
- Portal -> Google Drive publish
- provider adapterとしてMicrosoft Graph / Boxを追加
- conflict解消UI
