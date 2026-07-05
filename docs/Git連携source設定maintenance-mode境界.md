# Git連携 source 設定 maintenance-mode 境界

## 目的

`READ_ONLY_MAINTENANCE` 中は Git 連携 source の設定変更だけを停止し、設定確認と同期履歴の read-only 確認は継続します。

## 停止する操作

- `Admin::GitImportSourcesController#create`
- `Admin::GitImportSourcesController#update`
- `Admin::GitImportSourcesController#destroy`

maintenance mode ON では、repository、branch、source path、認証方式、credential、enabled 状態の保存・削除を開始しません。停止時は Git連携設定一覧へ戻し、操作者が理由を読める alert を表示します。

## 継続する read-only 操作

- Git連携設定一覧の表示
- repository / branch / source path / enabled 状態の検索・filter
- project / repository の remote picker と selected restore
- Git同期履歴一覧の確認

## 非目標

- `Admin::GitImportSourcesController#sync` の停止
- Git import runner の変更
- GitImportRun 保存 contract の変更
- GitHub App / PAT / no_auth の credential policy 変更
- branch / path picker の追加
- 削除候補 policy の変更

## 検証観点

- maintenance mode ON で create / update / destroy が `GitImportSource` を保存・削除しないこと
- maintenance mode ON でも一覧、filter、project lookup、Git同期履歴が読めること
- maintenance mode OFF では既存 CRUD が維持されること
