# 文書一括編集 maintenance mode 境界

このメモは `READ_ONLY_MAINTENANCE` 中の文書一括編集 dry-run / 実行で、止める状態変更と残す read-only 確認を整理します。

## current support

`READ_ONLY_MAINTENANCE` が有効なときは、次の状態変更を開始しません。

- 新しい文書一括編集 dry-run の作成
- 既存 dry-run の確認実行
- dry-run 実行に伴う `Document` / `DocumentVersion` / tag / archive state の更新
- dry-run 実行に伴う bulk edit access log の作成

停止時は 500 ではなく、管理者へメンテナンス中のため文書一括編集 dry-run の作成と実行が停止していることを alert で表示します。

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり dry-run 作成と確認実行を行います。

## read-only に維持するもの

maintenance mode 中でも、次の確認導線は止めません。

- `GET /admin/bulk_edit_dry_runs/new` の対象選択画面
- `POST /admin/bulk_edit_dry_runs/handoff` の選択状態 JSON
- `GET /admin/bulk_edit_dry_runs/:public_id` の既存 dry-run detail
- 文書マスタ一覧からの候補引き継ぎ表示
- dry-run detail 上の preview summary / warning / error / diff / 実行結果確認

`handoff` は dry-run 作成や bulk edit 実行を行わず、選択中 ID と代表条件を bounded に確認するための read-only 導線として残します。

## 非目標

この slice では次を変更しません。

- `BulkEditDryRun` の DB schema
- dry-run schema / warning contract
- `DocumentBulkEditPreview` / `DocumentBulkEditExecutor` の実行仕様
- 文書 model、権限 model、lifecycle / retention policy
- bulk edit の承認 workflow 化
- 非同期実行、予約実行、rollback 実行、bulk delete
- production infra 側の maintenance page

## 関連

- `app/controllers/admin/bulk_edit_dry_runs_controller.rb`
- `spec/requests/admin_bulk_edit_maintenance_spec.rb`
- `docs/文書一括編集dry-run運用runbook.md`
- `docs/文書マスタ運用runbook.md`
- `docs/本番運用・インフラ前提.md`
