# Internal upload API naming

## 方針

internal API は、用途が分かる名前に分ける。

- `POST /api/internal/artifact_imports`
  - GitHub Actions や build pipeline が生成済みの artifact と manifest を取り込む入口。
  - `artifact_root` と `manifest_path` を受け取る。
- `POST /api/internal/zip_uploads`
  - ZIP ファイルをアップロードして dry-run を作る入口。
  - `zip_file` と `project_code` を受け取る。
- `POST /api/internal/file_uploads`
  - 同期クライアントや手動アップロードから単体ファイルを受ける入口。
  - `file`、`project_code`、`relative_path` を受け取る。

詳細な呼び出し例・パラメータ仕様は [docs-src/api-specification.md](../../docs-src/api-specification.md) および [docs-src/client-file-upload-api.md](../../docs-src/client-file-upload-api.md) を参照する。

`doc_imports` は、実態が document file upload ではなく artifact import だったため、新しい用途名では使わない。
`zip_imports` は、internal API としてはファイル受信口であることが分かるよう `zip_uploads` に改名した。

## file_uploads の扱い

`file_uploads` は、受信した単体ファイルを一時ZIPとして staging し、既存の ZIP upload dry-run / manifest / `DocumentImporter` の流れへ合流させる。

パラメータ仕様・hash の扱い・path validation・レスポンス例の詳細は [docs-src/client-file-upload-api.md](../../docs-src/client-file-upload-api.md) を参照。

## dry-run の本実行

upload 系APIは dry-run を作った入口と、本実行の入口を一致させる。

- `zip_uploads` で作った dry-run は `zip_uploads` で実行する。
- `file_uploads` で作った dry-run は `file_uploads` で実行する。
- 別APIの `import_dry_run_id` を渡しても実行しない。

これにより、ZIP一括アップロードと単体ファイルアップロードの取り違えを防ぐ。

## 現状

- `config/routes.rb` では新しい3系統の internal API だけを公開する。
- 旧 `doc_imports` / `zip_imports` ルートは公開しない。
- 旧 `Api::Internal::DocImportsController` / `Api::Internal::ZipImportsController` は削除済み。
- request spec は `artifact_imports_spec` / `zip_uploads_spec` / `upload_routes_spec` と file upload 補助 spec に整理済み。

## 後方互換

このAPI群はまだ利用者がいない前提のため、後方互換は維持しない。
旧URLへ互換ルートやリダイレクトは置かない。
