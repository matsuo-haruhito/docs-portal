# internal upload API dry-run・apply運用 runbook

この文書は issue `#739` に対応する、`docs-portal` の internal upload API 運用メモです。

## 1. この runbook が扱う入口

この runbook では、同じ importer pipeline を使いながら入口が分かれている次の 3 系統を扱います。

- `POST /api/internal/artifact_imports`
- `POST /api/internal/zip_uploads`
- `POST /api/internal/file_uploads`

最初の見分け方は次です。

| 入口 | 誰が使うか | dry-run を作る request | apply を行う request |
| --- | --- | --- | --- |
| `artifact_imports` | GitHub Actions や build pipeline | `validate_only=true` を付けて `artifact_root` と `manifest_path` を送る | `validate_only` を付けずに `artifact_root` と `manifest_path` を送る |
| `zip_uploads` | 管理者が ZIP 一括アップロードで取り込むとき | `validate_only=true` を付けて `zip_file` と `project_code` を送る | `import_dry_run_id` を付けて同じ `zip_uploads` へ送る |
| `file_uploads` | 同期クライアントや単体ファイルの手動取り込み | `file` を付けて送る。`validate_only=true` は省略できる | `import_dry_run_id` を付けて同じ `file_uploads` へ送る |

`zip_uploads` と `file_uploads` は「アップロード request で dry-run を作り、保存済み dry-run を同じ API へ戻して apply する」流れです。
`artifact_imports` だけは、生成済み artifact と manifest を直接 apply できる入口として残っています。

## 2. 最初に確認する順番

1. 取り込み元が build artifact なのか、ZIP なのか、単体ファイルなのかを決める
2. dry-run を作る request なのか、保存済み dry-run を apply する request なのかを決める
3. `validate_only`、`file`、`zip_file`、`import_dry_run_id` のどれが今回の切り分け軸かを見る
4. dry-run を使う flow なら、response の `dry_run_id`、`status`、`expires_at` を控える
5. apply 前に、dry-run の `status` が `analyzed` のままかを確認する

mode を取り違えると、`zip_uploads` / `file_uploads` では apply できません。まず「どの API で dry-run を作ったか」を固定してから見直します。

## 3. `artifact_imports` の見方

`artifact_imports` は、すでに展開済みの artifact と `publish.json` を受け取る入口です。

### dry-run を作る request

- `validate_only=true`
- `artifact_root`
- `manifest_path`

current controller は、この request で `ImportManifestDryRun` を走らせ、`dry_run_id`、`status`、`expires_at` を返します。
`project_code` は request では受けず、manifest 内の project 群から `ImportDryRun.project` を推定します。

### apply を行う request

- `artifact_root`
- `manifest_path`
- 必要なら `import_dry_run_id`

current code では `import_dry_run_id` がなくても apply 自体はできます。
ただし、dry-run を経由して apply する運用では、`import_dry_run_id` が `analyzed` の dry-run を指していることと、manifest の `source_commit_hash` が dry-run 保存時と食い違っていないことを確認します。

### この入口で困ったとき

- `DOC_IMPORT_ACTOR_EMAIL is not configured` や `Import actor not found` が返る: import actor 設定を先に確認する
- `source_commit_hash does not match the confirmed dry-run` が返る: dry-run 作成後に別 commit の manifest を apply しようとしている
- dry-run を使うつもりで `import_dry_run_id` を付けていない: current code では apply できるが、運用上は dry-run との対応づけが薄くなる

## 4. `zip_uploads` の見方

`zip_uploads` は、アップロードされた ZIP を staging して dry-run を作る入口です。

### dry-run を作る request

- `validate_only=true`
- `zip_file`
- `project_code`
- 必要に応じて `source_repo`、`source_branch`、`source_commit_hash`、`version_label`、`status`

current controller は、ZIP 展開後の manifest と `zip_import_preview` を dry-run に保存します。
response でも `dry_run_id`、`status`、`expires_at`、`zip_import_preview` を返します。

### apply を行う request

- `import_dry_run_id`

apply request では `zip_file` を送りません。controller は保存済み dry-run の `artifact_root` と `manifest_path` を使って importer を呼びます。
`import_dry_run_id` は `status: analyzed` かつ `import_mode: zip` の dry-run である必要があります。

### この入口で困ったとき

- `import_dry_run_id is required for ZIP upload execution`: apply request に dry-run ID が付いていない
- `ZIP dry-run artifact is missing`: 保存済み dry-run に `artifact_root` / `manifest_path` が無い
- すでに `confirmed` や `expired` の dry-run を使っている: 同じ ID を再利用せず、ZIP をアップロードし直す

`zip_uploads` の日常運用で画面を見ながら確認するときは、[ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) を正本にします。

## 5. `file_uploads` の見方

`file_uploads` は、単体ファイルを受けてサーバー側で一時 ZIP 化し、ZIP upload と同じ importer pipeline へ流す入口です。

### dry-run を作る request

- `file`
- `project_code`
- 必要に応じて `relative_path`、`original_filename`、`source_path`、`source_name`、`content_hash`、`source_commit_hash`、`version_label`、`status`

この入口では `file` がある request が dry-run 作成として扱われます。
そのため `validate_only=true` は省略できます。付けても同じく dry-run 作成です。
response では `file_upload_preview` が返り、`source_name`、`relative_path`、`source_path`、`content_hash`、採用後の `source_commit_hash`、`version_label` を確認できます。

### apply を行う request

- `import_dry_run_id`

apply request では `file` を送りません。`zip_uploads` と同じく、保存済み dry-run に入っている `artifact_root` と `manifest_path` を使って importer を呼びます。
`import_dry_run_id` は `status: analyzed` かつ `import_mode: manual_upload` の dry-run である必要があります。

### `relative_path` と `source_path` の違い

- `relative_path`: 取り込み対象を識別するための安全な相対 path
- `source_path`: クライアント PC 上のフルパスなど、参考情報として残す path

current code は `relative_path` の先頭 `/`、`../`、Windows drive path を拒否します。
`source_path` は参考情報であり、保存先決定には使いません。

### `content_hash` と `source_commit_hash` の見方

- `content_hash` はアップロード元ファイル実体の SHA-256 と照合する
- `source_commit_hash` が request にあれば、それを採用値として優先する
- どちらも無ければ、アップロード元ファイル実体の SHA-256 を `source_commit_hash` として採用する

### この入口で困ったとき

- `file` を付けたつもりで apply まで進めてしまった: `file_uploads` では `file` 付き request は dry-run 作成側になる
- `content_hash does not match uploaded file`: クライアントが送ったハッシュと実体が一致していない
- `relative_path is invalid`: `../`、先頭 `/`、Windows drive path など unsafe path が含まれている

## 6. `validate_only` と `import_dry_run_id` の読み分け

切り分けの要点は次です。

- `validate_only=true`
  - `artifact_imports`: dry-run を保存する明示フラグ
  - `zip_uploads`: dry-run を保存する明示フラグ
  - `file_uploads`: `file` があれば省略できる。付けても dry-run 作成の意味は同じ
- `import_dry_run_id`
  - `zip_uploads` / `file_uploads`: apply に必須
  - `artifact_imports`: current code では任意だが、dry-run と apply の対応づけに使える

同じ `import_dry_run_id` でも API をまたいで流用はできません。
`zip_uploads` で作った dry-run は `zip_uploads` へ、`file_uploads` で作った dry-run は `file_uploads` へ戻します。

## 7. 再作成した方が早いとき

次のようなときは、同じ dry-run ID にこだわらず作り直した方が早いです。

- dry-run の `status` が `confirmed`、`expired`、`failed` になっている
- `artifact_root` や `manifest_path` が保存されていない
- `source_commit_hash` が変わった manifest を apply しようとしている
- `relative_path` や `content_hash` の入力を直したい
- ZIP や単体ファイルの中身自体を差し替えた

## 8. current support の境界

- この runbook は current controller behavior と request parameter の見分け方を扱います
- importer 本体の仕様、preview JSON の詳細 schema、version 管理の設計は [importと変更系dry-run](./specs/import%E3%81%A8%E5%A4%89%E6%9B%B4%E7%B3%BBdry-run.md) と [Internal upload API naming](./internal_upload_api_naming.md) を正本にします
- admin UI で ZIP dry-run を確認する画面運用は [ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) を正本にします
- build artifact を生成する CI 側の確認順は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) を正本にします

## 9. 関連文書

- [importと変更系dry-run](./specs/import%E3%81%A8%E5%A4%89%E6%9B%B4%E7%B3%BBdry-run.md)
- [Internal upload API naming](./internal_upload_api_naming.md)
- [ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md)
- [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md)
- [README](../README.md)
- [docs/README](./README.md)