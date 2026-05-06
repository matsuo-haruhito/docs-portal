# importと変更系dry-run

この文書は、import、dry-run、変更前確認系の正本です。

## 文書一括編集 dry-run

- 専用 UI より先に、文書一括編集の logic 層と保存付き dry-run を提供する
- 保存モデルは `BulkEditDryRun` とする
- dry-run / 実行ロジックは `DocumentBulkEditPlan`, `DocumentBulkEditPreview`, `DocumentBulkEditExecutor` で扱う
- 初期対象は `Document` の metadata、`Document.latest_version` の一部属性、`document_tags` の追加 / 削除、archive / restore に限定する

## Import dry-run

- `ImportDryRunValidator` は source path 妥当性、既存 Document 更新候補、分類推定、重複候補を dry-run 結果として返す
- `ImportManifestDryRun` は manifest 内の document 群を project ごとに束ね、internal import API の validation mode で共通 dry-run 結果を返す
- internal import API `POST /api/internal/doc_imports` は `validate_only=true` で dry-run を保存する

## ZIP upload import

- internal ZIP import API `POST /api/internal/zip_imports` は ZIP を `storage/imports/zip_uploads/...` に安全に展開したうえで manifest を自動生成する
- preview には `zip_import_preview` として `orphan_files`, `skipped_files`, `warnings` を含める
- 初期実装では Markdown / MDX / markdown 拡張子の文書、および standalone diagram を import 対象にする
- 本実行は保存済み `ImportDryRun(import_mode=zip)` の `dry_run_id` を指定して行う

## Git連携 import

- Git リポジトリから指定 branch / path 配下の Markdown と添付を取り込めるようにする
- push 型 internal import API と pull 型 Git 同期で、`DocumentImporter` を共通利用する
- 取り込み元 repository / branch / source_path / commit SHA を追跡する
- Git 側で削除されたファイルは即 delete せず、同期結果の削除候補として記録する

## import

- `DocumentImporter` は manifest と artifact を入力として、`Document`, `DocumentVersion`, `DocumentFile`, `PublishJob` を更新する
- `DocumentVersion` の source path metadata を保存する
- 同一 Document + version_label の重複 import は失敗させる
- 既存 Document の新 Version 候補は、同一 source path または十分に狭い既存文書一致で判定する

## publish manifest

- `publish.json` は Rails 取り込み用の確定 manifest として扱う
- `source_repo`, `source_branch`, `source_commit_hash`, `documents[]` を基本要素とする
- 文書 repo や CI から取り込む場合も、最終的にはこの manifest 形式へ揃える
