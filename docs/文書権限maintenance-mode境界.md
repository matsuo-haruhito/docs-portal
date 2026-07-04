# 文書権限 maintenance mode 境界

このメモは、`READ_ONLY_MAINTENANCE` 中の文書権限 CRUD の扱いを確認するための境界メモです。

## 対象

対象は `Admin::DocumentPermissionsController#create` / `#update` / `#destroy` です。

maintenance mode ON では、会社単位またはユーザー単位の文書権限について、次の変更を開始しません。

- 新規作成
- access level 変更
- 付与先の会社 / ユーザー変更
- 削除

停止時は `admin/document_permissions` へ戻し、管理者が停止理由を読める alert を表示します。

## read-only に残すもの

maintenance mode ON でも、次の確認導線は read-only として継続します。

- 文書別の権限概要
- 権限一覧
- 案件 / 文書名 / 権限 / 付与先の filter
- 文書 / 案件 / 会社 / ユーザーの remote search と selected restore
- CSV 出力

CSV は現在の filter 条件に一致する個別付与行を確認するための admin-only 出力です。maintenance mode ON でも保存や削除を行うものではありません。

## 非対象

この境界メモでは、次は変更しません。

- `DocumentPermission` model
- `ProjectMembership` model
- visibility policy
- 会社 / ユーザー排他制約
- アクセス申請承認 workflow
- 権限 resolver
- DB schema
- bulk grant / CSV import / 自動権限付与
- 文書権限画面全体の redesign

## 確認観点

request spec では、maintenance mode ON で `DocumentPermission` が増えない、更新されない、削除されないことを確認します。

あわせて、maintenance mode ON でも一覧、CSV、検索 endpoint が 200 で読めることを確認します。maintenance mode OFF の既存 CRUD は既存 request spec に残します。
