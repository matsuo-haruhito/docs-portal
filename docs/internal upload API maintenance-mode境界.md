# internal upload API maintenance-mode 境界

この文書は issue `#4561` に対応する、`READ_ONLY_MAINTENANCE` 中の internal upload API apply 停止境界を整理するメモです。

## 対象

対象は次の apply request です。

- `POST /api/internal/artifact_imports`
  - `validate_only` なしの direct apply
  - `import_dry_run_id` 付きの git_push dry-run apply
- `POST /api/internal/zip_uploads`
  - `import_dry_run_id` 付きの ZIP dry-run apply
- `POST /api/internal/file_uploads`
  - `import_dry_run_id` 付きの manual upload dry-run apply

## maintenance mode ON の挙動

`READ_ONLY_MAINTENANCE` が有効な間、上記 apply request は importer 実行前に停止します。

- `DocumentImporter` を呼びません。
- `PublishJob` を作成しません。
- `ImportDryRun` を `confirmed` にしません。
- `confirmed_by` / `confirmed_at` を更新しません。
- response は 500 ではなく、API client が理由を読める JSON error です。

## maintenance mode 中も残すもの

この first slice では dry-run 作成を止めません。

dry-run 作成は新しい `ImportDryRun` や staging metadata を保存するため read-only ではありませんが、apply 停止とは別の運用判断として残します。

- `artifact_imports` の `validate_only=true` dry-run 作成
- `zip_uploads` の `validate_only=true` dry-run 作成
- `file_uploads` の `file` 付き manual upload dry-run 作成
- `admin/file_upload_dry_runs` の一覧 / detail など既存 dry-run の確認

## maintenance mode OFF の確認

`READ_ONLY_MAINTENANCE` が無効な場合は既存の apply flow を維持します。

- artifact direct apply は `PublishJob` を返し、direct apply log を残します。
- `import_dry_run_id` 付き apply は対象 dry-run を `confirmed` にします。
- mode mismatch、commit mismatch、safe path validation、token 認証は既存 controller の責務のままです。

## 非対象

- importer pipeline の再設計
- manifest schema / preview JSON の変更
- dry-run retention / staging cleanup policy の変更
- `DOC_IMPORT_TOKEN` / `DOC_IMPORT_ACTOR_EMAIL` / 認証方式の変更
- external API 公開化
- production infra 側の maintenance page
