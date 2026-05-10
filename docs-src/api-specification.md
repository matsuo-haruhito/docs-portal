---
slug: /api-specification
---

# API仕様

このページは、文書ポータルの管理者向けに、ドキュメント更新用 internal import API の利用方法をまとめたものです。
GitHub Actions 専用APIではなく、Git push や ZIP アップロードなどの更新フローから呼び出される、ポータル側の取り込みAPIとして扱います。

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

## 運用メモ

- `validate_only=true` で事前検証し、差分や警告を確認してから本実行します。
- `source_commit_hash` が manifest と dry-run で食い違う場合、本実行は拒否されます。
- ZIP 取り込みの本実行では `import_dry_run_id` が必須です。
- 取り込み失敗時は管理画面の Git同期履歴、または import dry-run の結果を確認します。
- このMarkdownを更新した場合は Docusaurus build も更新し、`docusaurus/build/api-specification/index.html` が生成されることを確認します。

## 関連ページ

- 管理メニュー: Git取込元
- 管理メニュー: Git同期履歴
- 管理メニュー: 文書
