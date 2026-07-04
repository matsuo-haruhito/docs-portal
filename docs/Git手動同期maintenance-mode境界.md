# Git手動同期 maintenance-mode 境界

## 目的

`READ_ONLY_MAINTENANCE` 中は、管理画面からの Git 手動同期起動だけを停止します。Git連携設定の確認、編集画面の閲覧、Git同期履歴の確認は read-only な運用確認として継続します。

## current support

- `Admin::GitImportSourcesController#sync` は maintenance mode ON で `GitImportSourceSyncer` を呼びません。
- maintenance mode ON では `GitImportRun` の作成、同期 job、外部 fetch、import 実行を開始しません。
- 停止時は Git連携設定の編集画面へ戻し、管理者がメンテナンス中であることを読める alert を表示します。
- maintenance mode OFF では既存の手動同期成功導線と `admin/git_import_runs` への redirect を維持します。
- `admin/git_import_sources#index` / `edit` と `admin/git_import_runs#index` は maintenance mode ON でも閲覧できます。

## 非目標

- Git 同期本体の再設計
- GitHub App / Fine-grained PAT / no_auth の credential 保存方式変更
- `GitImportRun` schema や status model の変更
- branch / path picker の仕様変更
- 外部フォルダ同期、internal upload API、全 admin 変更系操作の一括停止
- production infra / LB / CDN 側 maintenance page の変更
