# アクセス申請 maintenance mode 境界

このメモは `READ_ONLY_MAINTENANCE` 中のアクセス申請まわりで、止める状態変更と残す read-only 確認を整理します。

## current support

`READ_ONLY_MAINTENANCE` が有効なときは、次の状態変更を開始しません。

- 利用者側のアクセス申請送信
- 利用者側の pending 申請取消
- internal admin による承認
- internal admin による却下

停止時は 500 ではなく、元の文脈へ戻して、メンテナンス中のためアクセス申請の状態変更が停止していることを alert で表示します。

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり申請送信、取消、承認、却下を行います。

## read-only に維持するもの

maintenance mode 中でも、次の確認導線は止めません。

- 利用者側のアクセス申請一覧
- 利用者側一覧の検索、status filter、要求権限 filter、対象種別 filter、pagination
- admin 側アクセス申請一覧
- admin 側アクセス申請 detail
- admin 側 pending handoff JSON

これらは状態確認と引き継ぎのための導線であり、承認、却下、通知、担当者割当、SLA、自動 escalation、一括処理を開始するものではありません。

## 非目標

この slice では次を変更しません。

- `AccessRequest` の DB schema
- `AccessRequest` status model
- `AccessRequestResolver` の権限付与 mapping
- 認可条件、company master admin / admin role 境界
- 承認 policy、通知、SLA、自動承認、自動 escalation
- pending handoff の export / API 化
- 全利用者向け変更系操作の一括停止

## 関連

- `app/controllers/access_requests_controller.rb`
- `app/controllers/admin/access_requests_controller.rb`
- `spec/requests/access_request_maintenance_spec.rb`
- `docs/利用者向けアクセス申請runbook.md`
- `docs/アクセス申請・同意管理・Webhook運用runbook.md`
- `docs/本番運用・インフラ前提.md`
