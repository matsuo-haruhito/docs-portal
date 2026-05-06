# publish.json 仕様と生成ルール

この sample では、`publish.json` を GitHub Actions で自動生成し、Rails ポータルへ渡します

## 1. 入力ファイル

入力は [publish/documents.json](./publish/documents.json) とします

- `publish/documents.json` は文書 repo 側の公開対象一覧
- `publish.json` は Rails 取り込み用の確定 manifest

という役割分担にします

## 2. documents.json の考え方

- `documents.json` には公開候補を列挙する
- `status: "published"` のものだけ manifest へ入れる
- `status` が `draft` または `archived` のものは manifest へ入れない
- 配布ファイルの `file_size` は未指定なら生成時に自動補完する
- 同一 `slug + version_label` の再公開はしない
- 修正版は `v1.0.1` のように版を上げる
- バージョン管理しない Document は、同一 Document を上書きする

例:

```json
{
  "documents": [
    {
      "project_code": "pj001",
      "slug": "dispatch-operation-manual",
      "title": "配車運用マニュアル",
      "category": "manual",
      "document_kind": "markdown",
      "visibility_policy": "restricted_external",
      "version_label": "v1.1.0",
      "status": "published",
      "changelog_summary": "画面説明を追加",
      "markdown_entry_path": "pj001/dispatch-operation-manual/v1.1.0",
      "site_build_path": "pj001/dispatch-operation-manual/v1.1.0",
      "pdf_snapshot_path": "pj001/dispatch-operation-manual/v1.1.0/manual.pdf",
      "files": [
        {
          "file_name": "manual.pdf",
          "content_type": "application/pdf",
          "storage_key": "pj001/dispatch-operation-manual/v1.1.0/manual.pdf"
        }
      ]
    }
  ]
}
```

## 3. 生成される publish.json

GitHub Actions では、次の項目を付与して `publish/manifest/publish.json` を生成します

- `source_repo`
- `source_branch`
- `source_commit_hash`
- `documents`

`documents` の各要素は、Rails の `DocumentImporter` がそのまま読める形式に揃えます

## 4. ファイル配置の前提

- `site_build_path`
  - `docusaurus/build/` 配下の相対パス
- `storage_key`
  - `attachments/` 配下の相対パス

Rails 側では次の保存先へコピーします

- HTML
  - DocumentVersion の site root 配下へ配置する
  - site root の実体パスは Rails 側の実装に従う
  - 利用者や文書 repo 側は site root の内部命名に依存しない
- 添付
  - `storage/document_files/<storage_key>` へ配置する

## 5. 生成スクリプト

生成は [scripts/generate_publish_manifest.mjs](./scripts/generate_publish_manifest.mjs) で行います

実行例:

```bash
node ./scripts/generate_publish_manifest.mjs \
  --config ./publish/documents.json \
  --output ./publish/manifest/publish.json \
  --repository example/docs-repo \
  --branch main \
  --sha abc123
```

## 6. バリデーション方針

生成時に次を確認します

- `status: "published"` の document だけを出力対象にする
- 公開対象の `site_build_path` が存在する
- `files` に書かれた添付ファイルが存在する
- 添付の `file_size` を取得できる
- `storage_key` は `attachments/` 配下の相対パスとして解決できる
- `site_build_path` は `docusaurus/build/` 配下の相対パスとして解決できる
- `version_label` は表示・識別用として妥当な文字列である

不足があれば Actions を失敗させます

## 7. 運用ルール

- `publish.json` は手編集しない
- 人が編集するのは `publish/documents.json`
- 同じ `slug + version_label` の再公開はしない
- 修正版は `v1.0.1` のように版を上げる
- `draft` は build しても Rails import の manifest には入れない
- `archived` は公開 manifest には入れない
