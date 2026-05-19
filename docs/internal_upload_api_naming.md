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

クライアントPC上のフルパスは `source_path` として参考情報に留め、取り込み上の安全な識別子には `relative_path` を使う。
`relative_path` は先頭 `/` や `../` を拒否し、サーバー側の保存先決定には使わない。

## 現状

- `config/routes.rb` では新しい3系統の internal API だけを公開する。
- 旧 `doc_imports` / `zip_imports` ルートは公開しない。
- 旧 `Api::Internal::DocImportsController` / `Api::Internal::ZipImportsController` は削除済み。
- request spec は `artifact_imports_spec` / `zip_uploads_spec` / `upload_routes_spec` に整理済み。

## 後方互換

このAPI群はまだ利用者がいない前提のため、後方互換は維持しない。
旧URLへ互換ルートやリダイレクトは置かない。
