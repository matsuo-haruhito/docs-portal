# 外部フォルダ同期 source 設定 maintenance-mode 境界

`READ_ONLY_MAINTENANCE` 中は、外部フォルダ同期 source の設定保存・削除だけを停止します。Google Drive / SharePoint / OneDrive の同期実行、provider API、OAuth lifecycle を同時に変更するものではありません。

## 停止する操作

- `Admin::ExternalFolderSyncSourcesController#create`
- `Admin::ExternalFolderSyncSourcesController#update`
- `Admin::ExternalFolderSyncSourcesController#destroy`

maintenance mode ON では、source 新規保存、provider / folder URL / auth type / metadata / enabled 状態の更新、source 削除を開始しません。停止時は管理画面へ戻し、設定と直近状態は確認できることを alert で案内します。

## 継続して確認できる操作

- 外部フォルダ同期 source 一覧
- source 詳細
- 検索 / provider filter / warning・error filter
- project search / selected project restore
- 直近 run、同期履歴、同期 item、受信 event の確認
- SharePoint / OneDrive の保存済み metadata 表示

## 対象外

- `dry_run` / `apply` / `force_apply` / `enqueue`
- Google Drive subscription `subscribe` / `unsubscribe`
- SharePoint / OneDrive metadata `recheck_metadata`
- source 配下 OAuth connection lifecycle
- Google Drive / Microsoft Graph provider API contract
- sync runner、storage schema、削除 policy
- DB schema / 認可条件 / admin-only 境界

## 検証観点

request spec では、maintenance mode ON で create / update / destroy が `ExternalFolderSyncSource` を保存・削除しないこと、一覧・詳細・検索・直近 run が read-only に確認できること、dry-run など実行系 action には今回の CRUD guard を追加していないこと、maintenance mode OFF の既存 CRUD が維持されることを確認します。
