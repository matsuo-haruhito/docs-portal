# Microsoft Graph接続とOffice preview

この文書は、`docs-portal` で Office ファイルの inline preview を有効にするための接続前提と、運用時の確認観点をまとめた正本です。

preview 用の `MicrosoftGraphConnection` と、外部フォルダ同期元である `ExternalFolderSyncSource` の役割分担、`.env` に置く値との境界は [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) を参照してください。日常運用で `admin/microsoft_graph_connections` の一覧を見返すときは [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md) を併せて参照してください。

## 何のための設定か

- `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` は Office preview 対象です。
- Office preview は、案件ごとの `MicrosoftGraphConnection` を優先して使います。
- Graph preview が使えない場合は、Google Drive 由来 preview へ fallback します。

現在の viewer 側の正本は [docs/specs/閲覧画面とUI.md](./specs/閲覧画面とUI.md) です。この文書では、そこに書かれている動作を管理画面でどう成立させるかに絞って整理します。

## 接続マスタの登録先

- 管理画面の `Microsoft Graph接続` で登録します。
- route は `admin/microsoft_graph_connections` です。
- 案件ごとに紐づく設定です。
- 現行コードでは、案件に対して `enabled` な接続が複数あっても、preview では `id` の小さいものから 1 件だけを使います。運用上は 1 案件 1 接続を基本にしてください。

## 登録項目

| 項目 | 必須 | 役割 |
| --- | --- | --- |
| project | 必須 | どの案件の Office preview に使う接続かを決めます。 |
| name | 必須 | 管理画面で識別するための表示名です。案件内で一意にします。 |
| auth_type | 必須 | 現行実装は `client_credentials` のみです。 |
| tenant_id | 必須 | Microsoft Entra ID テナントを識別します。 |
| client_id | 必須 | アプリケーションを識別します。 |
| client_secret | 必須 | アプリケーション認証に使います。保存時は暗号化カラムです。 |
| drive_id | 必須 | preview 用一時アップロード先 Drive を識別します。 |
| preview_folder_path | 必須 | preview 用一時アップロード先の相対パスです。 |
| enabled | 任意 | preview 対象として使うかどうかを切り替えます。 |
| site_id | 任意 | 保存はできますが、現行の Office preview 必須項目ではありません。 |

### `preview_folder_path` の制約

`preview_folder_path` は空欄不可です。次の値は保存できません。

- `/` から始まる絶対パス
- `..` または `../...`
- 正規化すると `.` になる値

相対パスとして扱える値を使ってください。初期値は `docs-portal-previews` です。

## Graph 側の最小前提

現行コードで固定されているのは、次の動作要件です。

1. client credentials flow で access token を取得できること
2. 設定した Drive / Folder に preview 対象ファイルを一時アップロードできること
3. アップロードした drive item に対して preview URL を取得できること

この repo では、Azure / Microsoft Graph の permission 名までは固定していません。tenant 側の権限設計に合わせつつ、少なくとも上の 3 つが成立するアプリ権限構成にしてください。

## preview の選ばれ方

Office ファイルを embedded preview で開いたときは、次の順で URL を決めます。

1. 案件に有効な Microsoft Graph 接続があり、ファイルサイズが 250MB 以下なら Graph preview を試す
2. Graph preview が失敗したら、Google Drive 由来 preview を試す
3. Google Drive 由来 preview も使えなければ、preview 不可として扱う

### 250MB 制限

- Graph 側の simple upload は 250MB 超の Office ファイルには使いません。
- 250MB 超でも Google Drive fallback が成立すれば preview できます。
- fallback も使えない場合は、Office preview は使えません。

## Google Drive fallback が成立する条件

現行コードには 2 系統の fallback があります。

### 1. Google Drive 同期由来ファイルの preview

次のどれかから Google Drive item を特定できる場合、Google Drive viewer URL を組み立てます。

- `ExternalFolderSyncItem` に対象 `DocumentFile` / `DocumentVersion` / `Document` の対応が残っている
- `source_commit_hash`
- `storage_key`

Google ネイティブ形式では、元の mime type に応じて `docs.google.com/.../preview` を使います。その他は `drive.google.com/file/d/:id/preview` を使います。

### 2. Google Drive への一時 upload preview

Google Drive 同期由来でなくても、次がそろっていれば upload preview を使えます。

- `GOOGLE_DRIVE_PREVIEW_FOLDER_ID`
- `GOOGLE_DRIVE_OAUTH_CLIENT_ID`
- `GOOGLE_DRIVE_OAUTH_CLIENT_SECRET`
- 有効な `oauth_user` 方式の Google Drive 同期元に保存された refresh token

この経路では、対象ファイルを Google Drive の preview 用フォルダへ一時アップロードして preview URL を返します。

## 確認手順

1. 管理画面で対象案件の `Microsoft Graph接続` を 1 件だけ `enabled` で登録する
2. 対象案件に Office ファイルを持つ文書版を用意する
3. 文書詳細や版詳細から Office ファイルの inline preview を開く
4. Graph preview が開くことを確認する
5. 必要なら、Graph 接続を無効化した状態または Graph 側失敗時に Google Drive fallback が成立するか確認する

## よくある詰まりどころ

### 保存時に弾かれる

- `preview_folder_path` が空欄、絶対パス、`..` を含む相対パスになっている
- `name` が同一案件内で重複している
- `client_secret` を含む必須項目が空欄になっている

### preview が開かない

- 対象案件に `enabled` な Microsoft Graph 接続がない
- Graph 側で token 取得、一時 upload、preview URL 取得のいずれかが失敗している
- Office ファイルが 250MB を超えており、かつ Google Drive fallback も成立しない
- Google Drive fallback に必要な metadata または環境変数 / refresh token が不足している

## 関連ドキュメント

- [README](../README.md)
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md)
- [閲覧画面とUI](./specs/閲覧画面とUI.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
- [Google Drive外部フォルダ同期](./Google%20Drive%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F.md)
- [.env.example](../.env.example)
