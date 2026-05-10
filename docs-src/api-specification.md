---
slug: /api-specification
---

# API仕様・連携設定

このページは、文書ポータルの管理者向けに、ドキュメント更新用 internal import API と関連する外部連携の使い方をまとめたものです。
GitHub Actions 専用APIではなく、Git push、ZIP upload、Git pull 型同期、Webhook、Microsoft Graph などの更新・連携フローを扱う管理者向け仕様です。

## 共通仕様

- ベースパス: `/api/internal`
- 認証: Bearer token
- Token 環境変数: `DOC_IMPORT_TOKEN`
- 実行ユーザー: `DOC_IMPORT_ACTOR_EMAIL` に対応するユーザー
- レスポンス形式: JSON
- 取り込み対象パス: `storage/imports/` 配下のみ

```http
Authorization: Bearer ${DOC_IMPORT_TOKEN}
```

## Git push / build artifact 取り込み

### `POST /api/internal/doc_imports`

Docusaurus build などで生成済みの成果物を、ポータルの文書として取り込みます。

| パラメータ | 必須 | 内容 |
| --- | --- | --- |
| `artifact_root` | 必須 | 取り込み対象成果物のルートディレクトリ。`storage/imports/` 配下のみ指定可能 |
| `manifest_path` | 必須 | publish manifest のパス。`storage/imports/` 配下のみ指定可能 |
| `validate_only` | 任意 | `true` の場合は dry-run のみ実行 |
| `import_dry_run_id` | 任意 | 確認済み dry-run を本実行に紐づけるID |

### dry-run

```bash
curl -X POST https://portal.example.com/api/internal/doc_imports \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "artifact_root=/app/storage/imports/example-artifact" \
  -F "manifest_path=/app/storage/imports/example-artifact/publish.json" \
  -F "validate_only=true"
```

### 本実行

```bash
curl -X POST https://portal.example.com/api/internal/doc_imports \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "artifact_root=/app/storage/imports/example-artifact" \
  -F "manifest_path=/app/storage/imports/example-artifact/publish.json" \
  -F "import_dry_run_id=${DRY_RUN_ID}"
```

成功時は `201 Created` を返します。`status` は作成された `PublishJob` の状態です。

```json
{
  "publish_job_id": 123,
  "status": "imported",
  "import_dry_run_id": "dry_run_public_id"
}
```

## ZIP 取り込み

### `POST /api/internal/zip_imports`

ZIP ファイルをアップロードして、ポータルの文書として取り込みます。
ZIP 取り込みは dry-run を必須とし、本実行時には dry-run の成果物を再利用します。

| パラメータ | 必須 | 内容 |
| --- | --- | --- |
| `zip_file` | dry-run時必須 | 取り込み対象ZIP |
| `project_code` | dry-run時必須 | 取り込み先案件コード |
| `validate_only` | 任意 | `true` の場合は dry-run のみ実行 |
| `import_dry_run_id` | 本実行時必須 | dry-run で発行されたID |
| `source_repo` | 任意 | 元リポジトリ。未指定時は `zip_upload` |
| `source_branch` | 任意 | 元ブランチ。未指定時はアップロードファイル名 |
| `source_commit_hash` | 任意 | 元コミット。未指定時はZIPのSHA-256 |
| `version_label` | 任意 | 作成する文書版のラベル。未指定時は `zip-YYYYMMDDHHMMSS` |
| `status` | 任意 | 作成する文書版の公開状態。未指定時は `published` |

### dry-run

```bash
curl -X POST https://portal.example.com/api/internal/zip_imports \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "project_code=my-project" \
  -F "zip_file=@site.zip" \
  -F "validate_only=true"
```

### 本実行

```bash
curl -X POST https://portal.example.com/api/internal/zip_imports \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "import_dry_run_id=${DRY_RUN_ID}"
```

成功時は `201 Created` を返します。`status` は作成された `PublishJob` の状態です。

```json
{
  "publish_job_id": 123,
  "status": "imported",
  "import_dry_run_id": "dry_run_public_id"
}
```

## Git pull 型同期

管理メニューの **Git取込元** から、外部 Git repository を pull 型で同期できます。
Push 型と同じ `DocumentImporter` を使い、対象 repository / branch / source path 配下の Markdown と添付を manifest 化して取り込みます。

### GitHub 側の設定

現行実装で pull 同期に使える認証方式は、公開 repository 向けの `no_auth` と、private repository 向けの `fine_grained_pat` です。
画面上には `github_app` / `deploy_key` も選択肢としてありますが、pull 同期の実行処理ではまだ未実装のため、利用時は `fine_grained_pat` を選びます。

#### Fine-grained PAT の作成例

1. GitHub の対象 user または organization で fine-grained personal access token を作成する。
2. Resource owner に対象 owner / organization を選ぶ。
3. Repository access は取り込み対象 repository のみに絞る。
4. Repository permissions で **Contents: Read-only** を付与する。
5. private repository の一覧や repository metadata が必要な運用では **Metadata: Read-only** が利用できる状態にしておく。
6. 有効期限を設定し、発行された token を控える。
7. ポータルの **Git取込元** で認証方式 `fine_grained_pat` を選び、`認証シークレット` に token を入力する。

#### GitHub repository 側の準備例

```text
Repository: example-org/customer-docs
Branch: main
取り込み対象: docs/customer-a
必要な権限: Contents read
推奨: token の repository access は example-org/customer-docs のみに限定
```

#### GitHub App を使う場合の準備メモ

GitHub App 方式を使う場合は、GitHub 側で App を作成し、対象 repository に install して installation ID を控えます。
ただし現行の pull 同期実行処理では GitHub App installation token の発行が未実装のため、設定欄は将来利用のための予約項目です。

GitHub App を有効化する場合の想定設定は次のとおりです。

```text
GitHub App permissions: Contents read
Repository access: Only selected repositories
Installation target: example-org/customer-docs
ポータル側: 認証方式 github_app / GitHub App installation ID を設定
```

### ポータル側の設定項目

| 項目 | 設定例 | 内容 |
| --- | --- | --- |
| 案件 | `サンプル案件` | 取り込み先 Project |
| 連携先 | `github` | 初期実装の provider |
| Organization | `example-org` | 管理用メモ・検索用の組織名 |
| リポジトリ | `example-org/docs-repo` | `owner/repo` 形式 |
| ブランチ | `main` | 同期対象 branch |
| 取込元パス | `docs` | repository 内の相対 path。絶対 path や `../` は不可 |
| 認証方式 | `fine_grained_pat` | private repository の現行推奨。公開 repository は `no_auth` も可 |
| GitHub App installation ID | `12345678` | GitHub App 認証時の installation ID。現行 pull 実行では未使用 |
| 認証情報の参照名 | `github/docs-repo/import` | secret store などを使う場合の参照名 |
| 認証シークレット | `github_pat_...` | fine-grained PAT 利用時の secret。暗号化保存 |
| 状態 | `有効` | 無効の場合は同期不可 |

### 運用フロー

1. GitHub 側で fine-grained PAT を作成し、対象 repository の Contents read を付与する。
2. 管理メニューの **Git取込元** で設定を登録する。
3. 一覧または詳細から手動同期を実行する。
4. 対象 repository / branch を一時領域へ clone する。
5. `source_path` 配下の Markdown と添付を import manifest に変換する。
6. `DocumentImporter` が Document / DocumentVersion / DocumentFile を作成する。
7. 管理メニューの **Git取込履歴** で結果を確認する。

同じ commit SHA が既に同期済みの場合は `skipped` として記録し、新しい版は作りません。

### 設定例

```text
案件: サンプル案件
連携先: github
Organization: example-org
リポジトリ: example-org/customer-docs
ブランチ: main
取込元パス: docs/customer-a
認証方式: fine_grained_pat
認証シークレット: github_pat_...
状態: 有効
```

公開 repository の場合は次のように `no_auth` で同期できます。

```text
リポジトリ: example-org/public-docs
ブランチ: main
取込元パス: docs
認証方式: no_auth
状態: 有効
```

## Webhook 通知

管理メニューの **Webhook** から、文書更新や import 結果を外部システムへ通知する endpoint を登録できます。

### 設定項目

| 項目 | 設定例 | 内容 |
| --- | --- | --- |
| 名称 | `Slack通知` | 管理画面上の表示名 |
| 送信先URL | `https://example.com/webhooks/docs-portal` | HTTP/HTTPS の受信 endpoint |
| 署名シークレット | `change-me-long-random-secret` | 設定時は HMAC-SHA256 署名を付与 |
| 有効 | `true` | 無効時は送信しない |
| 通知対象イベント | `document_published`, `import_failed` | 購読する event type |

### 通知対象イベント

- `document_updated`
- `document_published`
- `import_completed`
- `import_failed`
- `review_approved`
- `qa_posted`
- `qa_answered`

### 送信ヘッダー

```http
Content-Type: application/json
X-Docs-Portal-Event: import_completed
X-Docs-Portal-Delivery: whdel_xxxxx
X-Docs-Portal-Signature-256: sha256=<hmac_sha256_hex>
```

`X-Docs-Portal-Signature-256` は、署名シークレットを設定した場合だけ付与されます。受信側では request body を同じ secret で HMAC-SHA256 署名し、値を比較します。

### payload 例

```json
{
  "id": "evt_xxxxx",
  "event_type": "import_completed",
  "occurred_at": "2026-05-11T12:00:00Z",
  "title": "Import completed",
  "body": "Documents were imported successfully",
  "project": { "public_id": "prj_xxxxx" },
  "document": { "public_id": "doc_xxxxx" },
  "document_version": { "public_id": "dver_xxxxx" },
  "actor": { "public_id": "usr_xxxxx" }
}
```

### 設定例

```text
名称: Import失敗通知
送信先URL: https://ops.example.com/hooks/docs-portal
署名シークレット: 32文字以上のランダム文字列
有効: true
通知対象イベント: import_failed, document_published
```

2xx 応答は成功、それ以外または例外は失敗として配信履歴に記録します。初期実装では自動再送キューは持たないため、受信側は `X-Docs-Portal-Delivery` を冪等キーとして扱えるようにしておくと安全です。

## Microsoft Graph / Office preview

管理メニューの **Microsoft Graph** から、Office ファイルのプレビュー用接続を案件ごとに設定できます。
`.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` の embedded file viewer で使用します。

### Microsoft Entra 側の設定

1. Microsoft Entra 管理センターでアプリ登録を作成する。
2. Application client ID と Directory tenant ID を控える。
3. Client secret を作成し、値を控える。
4. Microsoft Graph の application permission を追加する。
5. 管理者の同意を付与する。
6. preview 用の SharePoint / OneDrive for Business の Drive と folder を用意する。
7. Drive ID と preview folder の相対 path を控える。

このアプリは client credentials flow で `https://graph.microsoft.com/.default` を使って access token を取得します。
そのため、Entra のアプリ登録に付与済みの Microsoft Graph application permission が token に反映されます。

### 必要な Microsoft Graph 権限

現行実装では、対象ファイルを preview 用 Drive へアップロードし、その driveItem に対して `/preview` を呼び出します。
そのため、少なくとも次の操作ができる application permission が必要です。

- preview 用 Drive へのファイルアップロード
- アップロードした driveItem の preview URL 取得

標準的には、SharePoint / OneDrive for Business の Drive に対する application permission として `Sites.ReadWrite.All` を付与します。
テナントの権限設計でより狭い権限を採用する場合は、対象 site / drive に限定した権限設計を別途行います。

### SharePoint / Drive 側の準備例

```text
Site: https://contoso.sharepoint.com/sites/docs-preview
Drive: Documents
Preview folder: docs-portal-previews
Folder path rule: 相対 path のみ。先頭 / や ../ は不可
```

preview 用 folder は、ポータルが一時アップロードに使う領域です。
一般利用者が直接編集する領域とは分け、不要ファイルの定期削除方針を決めておきます。

### ポータル側の設定項目

| 項目 | 設定例 | 内容 |
| --- | --- | --- |
| 案件 | `サンプル案件` | 接続を使う Project |
| 接続名 | `Office preview` | 管理画面上の表示名 |
| 認証方式 | `client_credentials` | 初期実装の認証方式 |
| Tenant ID | `00000000-0000-0000-0000-000000000000` | Microsoft Entra tenant ID |
| Client ID | `11111111-1111-1111-1111-111111111111` | アプリケーション client ID |
| Client secret | `...` | アプリの client secret。暗号化保存 |
| Site ID | `contoso.sharepoint.com,...` | 任意。運用メモとして保持 |
| Drive ID | `b!xxxxxxxx` | preview 用ファイルを置く Drive ID |
| プレビュー用フォルダ | `docs-portal-previews` | Drive 内の相対 path。絶対 path や `../` は不可 |
| 状態 | `有効` | 無効時は preview に使わない |

### 運用フロー

1. Microsoft Entra ID でアプリ登録を作成する。
2. client credentials flow で Microsoft Graph を呼び出せるように権限を設定する。
3. SharePoint / OneDrive の preview 用 Drive と folder を用意する。
4. 管理メニューの **Microsoft Graph** で案件ごとに接続を登録する。
5. 利用者が Office ファイルを embedded viewer で開く。
6. Rails が対象ファイルを preview 用 folder へ一時アップロードし、Graph の driveItem preview URL を取得する。
7. iframe 内で Graph preview URL へ redirect する。

### 設定例

```text
案件: サンプル案件
接続名: Office preview
認証方式: client_credentials
Tenant ID: 00000000-0000-0000-0000-000000000000
Client ID: 11111111-1111-1111-1111-111111111111
Client secret: Microsoft Entra ID で発行した secret
Site ID: contoso.sharepoint.com,site-id,web-id
Drive ID: b!xxxxxxxxxxxxxxxx
プレビュー用フォルダ: docs-portal-previews
状態: 有効
```

250MBを超える Office ファイルは Graph へアップロードせず、「プレビュー不可・ダウンロードのみ」の案内を表示します。Graph preview URL は一時URLとして扱い、DBには永続化しません。

## 運用メモ

- `validate_only=true` で事前検証し、差分や警告を確認してから本実行します。
- `source_commit_hash` が manifest と dry-run で食い違う場合、本実行は拒否されます。
- ZIP 取り込みの本実行では `import_dry_run_id` が必須です。
- 取り込み失敗時は管理画面の Git同期履歴、または import dry-run の結果を確認します。
- Git pull 型同期では、同じ commit SHA の再同期は `skipped` になります。
- Webhook は送信履歴を確認し、失敗時は受信側のログと `WebhookDelivery` の response body を突き合わせます。
- Microsoft Graph preview が失敗した場合も、通常のダウンロード導線は残します。
- このMarkdownを更新した場合は Docusaurus build も更新し、`docusaurus/build/api-specification/index.html` が生成されることを確認します。

## 関連ページ

- 管理メニュー: Git取込元
- 管理メニュー: Git取込履歴
- 管理メニュー: Webhook
- 管理メニュー: Microsoft Graph
- 管理メニュー: 文書
