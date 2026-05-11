# Google Drive外部フォルダ同期

## 目的

Google Driveフォルダを外部文書置き場として登録し、docs-portalへ片方向で取り込むためのMVP仕様です。

この機能は Microsoft Graph / SharePoint / OneDrive の双方向同期を実装する前に、外部フォルダ同期の共通モデルとdry-run運用を小さく検証するために追加します。

## 初期MVPの対象

- providerは `google_drive` のみ
- 同期方向は `external_to_portal` のみ
- 競合方針は `manual` のみ
- 管理画面から手動で `dry-run` / `同期実行` を行う
- Google Drive側削除はportal側から物理削除せず、`delete_detected` として記録する

## 対象外

- PortalからGoogle Driveへの反映
- 双方向同期
- Google Drive側削除のportal側物理削除
- Webhook / push notification
- Google Docs / Sheets / SlidesなどGoogleネイティブ形式の変換取り込み
- OAuthユーザー認可フロー

## 認証

初期MVPでは Google Cloud のService Account JSONを管理画面へ登録します。

運用時は、同期対象のGoogle DriveフォルダをService Accountのメールアドレスへ共有してください。

登録した認証設定は `ExternalFolderSyncSource.auth_config` に暗号化保存します。

## 主なモデル

### ExternalFolderSyncSource

外部フォルダ同期元の設定です。

- project
- provider
- name
- folder_url
- external_folder_id
- external_folder_path
- sync_direction
- conflict_policy
- enabled
- auth_config
- last_synced_at
- last_error_message

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

## dry-run / apply

`dry-run` はGoogle Driveを列挙し、以下の予定を `ExternalFolderSyncRun.result_json` に保存します。

- `create`: portal側に未取り込み
- `update`: 既存取り込み済みだがchecksum / modified_at / pathが変化
- `skip`: 変更なし
- `error`: Googleネイティブ形式などMVP対象外

`apply` は `create` / `update` をportal側へ取り込み、Document / DocumentVersion / DocumentFileを作成します。

Google Drive側で見えなくなった既存itemは `delete_detected` として記録し、portal側Document / DocumentFileは保持します。

## 今後の拡張候補

- Google Docsネイティブ形式のexport取り込み
- OAuthユーザー認可
- Google Drive changes APIによる差分同期
- Portal -> Google Drive publish
- provider adapterとしてMicrosoft Graph / Boxを追加
- conflict解消UI
