# Microsoft Graph接続 maintenance-mode 境界

`READ_ONLY_MAINTENANCE` 中は、Microsoft Graph接続設定の保存・削除だけを停止します。Office preview runtime や Microsoft Graph / Azure 側の権限設計を変えるものではありません。

## 停止する操作

- `Admin::MicrosoftGraphConnectionsController#create`
- `Admin::MicrosoftGraphConnectionsController#update`
- `Admin::MicrosoftGraphConnectionsController#destroy`

maintenance mode ON では、次の変更を保存しません。

- 新しい Microsoft Graph接続の作成
- 既存接続の Tenant ID / Client ID / Client secret / Site ID / Drive ID / preview folder / enabled 状態の更新
- Microsoft Graph接続の削除

停止時は管理画面へ戻し、接続一覧と preview 利用状態は確認できることを案内します。

## 継続して確認できる操作

- Microsoft Graph接続一覧
- preview 利用状態、重複有効接続、検索 / filter
- 案件 remote search / selected project restore
- `共有URLから候補を取得（保存しない）`

共有 URL 候補取得はフォーム入力補助であり、接続設定を保存しません。そのため maintenance mode 中も候補確認として残します。候補を保存するには maintenance mode OFF 後に別途保存します。

## 対象外

- Office preview runtime
- Graph / Azure 側の権限設計
- secret rotation policy
- 接続選択ロジック
- SharePoint / OneDrive 同期本体
- 外部フォルダ同期 source CRUD / dry-run / apply
- DB schema / 認可条件 / admin-only 境界

## 確認

request spec では、maintenance mode ON で create / update / destroy が DB を変更しないこと、一覧と案件 lookup が read-only に使えること、共有 URL 候補取得が保存なしで使えること、maintenance mode OFF の既存 CRUD が維持されることを確認します。
