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
- 管理画面の「API仕様」は `docs-src/api-specification.md` を Docusaurus build した HTML として表示し、internal import API の呼び出し仕様を管理者向けに提示する

## ZIP upload import

- internal ZIP import API `POST /api/internal/zip_imports` は ZIP を `storage/imports/zip_uploads/...` に安全に展開したうえで manifest を自動生成する
- preview には `zip_import_preview` として `orphan_files`, `skipped_files`, `warnings` を含める
- 初期実装では Markdown / MDX / markdown 拡張子の文書、および standalone diagram を import 対象にする
- 本実行は保存済み `ImportDryRun(import_mode=zip)` の `dry_run_id` を指定して行う

### #88 初期完了範囲

#88 は、専用 UI より先に internal API と importer pipeline で ZIP import の初期スライスを提供できた時点で完了扱いにする。

完了範囲は次のとおり。

- ZIP upload を staging 領域へ安全に展開し、path traversal やファイル数 / 展開サイズの上限を検証する
- ZIP 内のフォルダ構造を `source_path` として保持した manifest を生成する
- ZIP import / Git import の `DocumentFile` は、添付の相対 path も保持して viewer 上の TreeView と ZIP 出力で再利用できるようにする
- Markdown / MDX / markdown 拡張子の文書候補と standalone diagram 候補を判定する
- README.md / index.md をフォルダ index 候補として扱う
- Markdown から参照される画像、PDF、Office などを添付候補として preview に含める
- `validate_only=true` で保存付き dry-run を作成し、登録予定の Document / Version / File と warning を確認できるようにする
- 保存済み dry-run を confirmed execution の入力として再利用し、manifest importer 経由で本実行できるようにする
- ZIP import の代表ケースを request / service spec で確認する

次の項目は #88 の完了条件からは外し、後続 issue で扱う。

- 専用の管理 UI
- 巨大 ZIP を前提にした非同期 Job 化、実行履歴、再実行、rollback / cleanup の強化
- 添付ファイルのウイルススキャン連携
- standalone diagram や未参照ファイルのより細かい自動分類
- 類似 Document 候補や重複検出の高度化

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
