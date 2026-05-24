# preview 接続と外部フォルダ同期の設定責務

この文書は、`docs-portal` で外部ストレージ連携を扱うときに、「何を管理画面へ登録するのか」「何を `.env` に置くのか」「どこまでが current support で、どこからが後続 issue の対象か」を 1 本で追えるように整理した補助ガイドです。

現時点の正本は各個別文書にあります。このページでは仕様を増やさず、既存 docs と current code の読み分けをしやすくすることだけを目的にします。

## 先に結論

| やりたいこと | 主な登録先 | 追加で見るもの | current support |
| --- | --- | --- | --- |
| Office ファイルの inline preview を Microsoft Graph で開く | 管理画面 `Microsoft Graph接続` | [Microsoft Graph接続とOffice preview](./Microsoft%20Graph接続とOffice%20preview.md) | 対応済み |
| Google Drive フォルダを portal へ取り込む | 管理画面 `外部フォルダ同期` | [Google Drive外部フォルダ同期](./Google%20Drive外部フォルダ同期.md) | 対応済み |
| Graph preview が失敗したときに Google Drive upload preview へ fallback する | 管理画面 `外部フォルダ同期` の OAuth 接続 + `.env` の `GOOGLE_DRIVE_*` | [Microsoft Graph接続とOffice preview](./Microsoft%20Graph接続とOffice%20preview.md) | 対応済み |
| SharePoint / OneDrive の共有 URL から同期元 metadata を解決する | まだ専用 UI / docs は未完成 | `#496`, `#552` | 未対応、後続 issue で検討中 |
| Microsoft Graph / SharePoint / OneDrive を同期元として dry-run / apply する | まだ専用 UI / docs は未完成 | `#503` | 未対応、後続 issue で検討中 |

## 何をどこに置くか

### 1. Microsoft Graph 接続

Office preview 用の接続です。管理画面の `admin/microsoft_graph_connections` で案件ごとに登録します。

主に保存するもの:

- `project`
- `name`
- `tenant_id`
- `client_id`
- `client_secret`
- `drive_id`
- `preview_folder_path`
- `enabled`
- `site_id` は任意メモ

この接続は、Office ファイルを preview するときに、一時 upload 先 Drive と preview URL 取得に使います。外部フォルダ同期元そのものではありません。

### 2. 外部フォルダ同期元

外部の文書置き場を portal へ取り込むための設定です。管理画面の `admin/external_folder_sync_sources` で登録します。

主に保存するもの:

- `project`
- `name`
- `provider`
- `folder_url`
- `auth_type`
- `external_folder_path`
- `sync_direction`
- `conflict_policy`
- `enabled`
- `auth_config`

現行 docs と current code で stable に説明できる provider は `google_drive` だけです。同期方向も `external_to_portal` のみです。

### 3. `.env` に置く値

外部連携まわりで `.env` に置く現行の runtime 前提は、基本的に Google Drive 系です。

| 変数 | 用途 |
| --- | --- |
| `GOOGLE_DRIVE_OAUTH_CLIENT_ID` | Google Drive OAuth user 方式と upload preview の client id |
| `GOOGLE_DRIVE_OAUTH_CLIENT_SECRET` | Google Drive OAuth user 方式と upload preview の client secret |
| `GOOGLE_DRIVE_PREVIEW_FOLDER_ID` | Google Drive upload preview の一時保存先 folder id |
| `GOOGLE_DRIVE_PREVIEW_UPLOAD_TTL_HOURS` | 一時 upload preview の有効時間 |

一方で、Microsoft Graph preview 用の `tenant_id` / `client_id` / `client_secret` / `drive_id` / `preview_folder_path` は、現行では `.env.example` ではなく管理画面の `MicrosoftGraphConnection` に保存する前提です。

つまり、Office preview を Microsoft Graph で使うだけなら、current docs の範囲では Graph 専用の環境変数を追加するより、まず管理画面の接続登録を確認します。

## 役割分担

### Office preview を成立させるもの

- `MicrosoftGraphConnection`
  - Office ファイルの inline preview 用
  - Graph token 取得、一時 upload、preview URL 取得に使う
- Google Drive preview fallback
  - Graph preview が失敗したときの代替経路
  - Google Drive 同期由来 metadata、または Google Drive upload preview を使う

### 外部文書を portal に取り込むもの

- `ExternalFolderSyncSource`
  - 外部フォルダの列挙、dry-run、apply、同期履歴の起点
  - current support は Google Drive の片方向同期

この 2 つは同じ「外部ストレージ連携」でも責務が違います。

- `MicrosoftGraphConnection` は preview 用接続
- `ExternalFolderSyncSource` は同期元設定

後続 issue で SharePoint / OneDrive 連携を進める場合も、この責務分離を前提に読むと混線しにくくなります。

## current support の読み方

### Google Drive

- 外部フォルダ同期: 対応済み
- OAuth user / service account: 対応済み
- upload preview fallback: 対応済み

### Microsoft Graph

- Office preview 用接続: 対応済み
- SharePoint / OneDrive の同期元 metadata 解決: 未対応
- Graph -> Portal の dry-run / apply: 未対応

### SharePoint / OneDrive

- 共有 URL から metadata を解決して同期元へ保存する流れ: `#496` の対象
- provider-aware な同期元作成 UI: `#552` の対象
- Graph -> Portal の手動同期: `#503` の対象

現時点では、SharePoint / OneDrive を「すでに Google Drive と同じ同期元として使える」と読まないでください。current docs から安全に言えるのは、関連 issue が切られており、役割分担の整理が必要だという段階までです。

## よくある判断

### Office preview を試したい

最初に見るのは `Microsoft Graph接続` です。Google Drive 同期元を先に作る必要はありません。

ただし、Graph preview が失敗したときの fallback まで確認したいなら、Google Drive 側の OAuth / preview folder 前提も必要です。

### Google Drive フォルダを portal に取り込みたい

最初に見るのは `外部フォルダ同期` です。`Microsoft Graph接続` は不要です。

### SharePoint / OneDrive の共有 URL を貼って同期したい

current main では docs 先行または後続 issue の整理段階です。`#496` `#503` `#552` を合わせて確認してください。

## 関連ドキュメント

- [README](../README.md)
- [docs/README](./README.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph接続とOffice%20preview.md)
- [Google Drive外部フォルダ同期](./Google%20Drive外部フォルダ同期.md)
- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)