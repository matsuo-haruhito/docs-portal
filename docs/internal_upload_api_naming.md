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

`doc_imports` は、実態が document file upload ではなく artifact import だったため、新しい用途名では使わない。
`zip_imports` は、internal API としてはファイル受信口であることが分かるよう `zip_uploads` に改名した。

## file_uploads の扱い

`file_uploads` は、受信した単体ファイルを一時ZIPとして staging し、既存の ZIP upload dry-run / manifest / `DocumentImporter` の流れへ合流させる。

`file` パラメータがあるリクエストは dry-run 作成として扱う。
そのため、同期クライアントや簡易アップローダーは `validate_only=true` を省略できる。
`validate_only=true` を付けても同じく dry-run 作成になる。
本実行時は `file` を送らず、`import_dry_run_id` だけを送る。

クライアントPC上のフルパスは `source_path` として参考情報に留め、取り込み上の安全な識別子には `relative_path` を使う。
`relative_path` は先頭 `/`、Windows の `C:/...` 形式、`../` を拒否し、サーバー側の保存先決定には使わない。
`relative_path` が未指定の場合は `original_filename`、それもなければ upload file の元ファイル名を fallback として使う。
この fallback 値も `relative_path` と同じ安全チェックを通す。

`content_hash` は同期クライアント向けの内容ハッシュ名として受け付ける。
指定された `content_hash` は `sha256:<hash>` 形式でも `<hash>` 形式でも受け付け、アップロードされた元ファイル実体の SHA-256 と常に照合する。
不一致の場合は dry-run を作らない。
`source_commit_hash` は artifact import と揃えるための採用ハッシュ名で、`content_hash` と両方ある場合、採用値としてはこちらを優先する。
どちらも指定されない場合、`file_uploads` は内部生成した一時ZIPではなく、アップロードされた元ファイル実体の SHA-256 を採用する。
これにより、同期クライアントが同じファイルを再送した場合にも、内容単位で追跡しやすくする。
`version_label` が指定されない場合は `file-YYYYMMDDHHMMSS-<hash8>` を使う。

`file_upload_preview` には、採用された `source_name`、`relative_path`、参考情報の `source_path`、`file_size`、検証済みの `content_hash`、採用後の `source_commit_hash`、`version_label`、および内部ZIP化後の `zip_import_preview` を返す。
レスポンスだけで dry-run の主要条件を確認できるようにする。

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
