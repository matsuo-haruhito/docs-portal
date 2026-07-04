# 会社 / ユーザー / 案件所属 maintenance mode 境界

`READ_ONLY_MAINTENANCE` 中は、会社・ユーザー・案件所属の変更操作だけを停止します。一覧、検索、selected endpoint による現在値確認は read-only に残します。

## current support

- `admin/companies#create` / `#update` / `#destroy` は保存・削除を開始しません。
- `admin/users#create` / `#update` / `#destroy` は保存・削除を開始しません。
- `admin/project_memberships#create` / `#update` / `#destroy` は保存・削除を開始しません。
- 停止時は 500 ではなく、操作者が理由を読める alert 付き redirect にします。
- `admin/companies#index` と `admin/users#index` の一覧、検索、filter、pagination は確認できます。
- `admin/users#company_search` / `#selected_company` は company_master_admin の自社 scope を保ったまま確認できます。
- `admin/project_memberships#index`、`project_search` / `selected_project`、`user_search` / `selected_user` は確認できます。

## 非目標

- 認可 policy、role model、会社境界、案件所属 contract の変更
- company_master_admin の権限拡大
- password reset、招待、通知、監査 policy の追加
- 全 admin CRUD の一括停止
- production infra 側 maintenance page の追加
- 案件、文書、文書権限、アクセス申請 workflow の変更

## 確認観点

- maintenance ON で会社 / ユーザー / 案件所属の create / update / destroy が保存・削除しないこと
- maintenance ON でも一覧、検索、selected endpoint が read-only に使えること
- maintenance OFF で既存の代表 CRUD が壊れていないこと
- company_master_admin の会社 / ユーザー scope が変わっていないこと
