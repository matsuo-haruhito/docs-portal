# 確認依頼 maintenance mode 境界

このメモは `DocumentApprovalRequest` のうち、`READ_ONLY_MAINTENANCE` 中に止める操作と、引き続き read-only に確認できる操作を短く整理します。

## current support

`READ_ONLY_MAINTENANCE` が有効なときは、文書詳細からの確認依頼新規作成を停止します。`DocumentApprovalRequestsController#create` は新しい `DocumentApprovalRequest` を保存せず、文書詳細へ戻して、メンテナンス中のため新規作成が停止していることを alert で表示します。

`READ_ONLY_MAINTENANCE` が有効なときは、pending 確認依頼の OK / Cancel も停止します。`DocumentApprovalRequestsController#update` と `#cancel` は `approve!` / `cancel!` を呼ばず、`status`、`acted_by`、`approved_at`、`cancelled_at` を変更しません。停止時は確認依頼 detail へ戻して、メンテナンス中のため OK / Cancel が停止していることを alert で表示します。

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり確認依頼を作成し、pending 依頼を OK / Cancel できます。validation error の扱い、requester 設定、approver 指定、文書詳細への戻り先、internal user / requester の権限境界は既存 flow を正本とします。

## read-only に維持するもの

maintenance mode 中でも、次の確認導線は止めません。

- 確認依頼の全体一覧
- 文書配下の確認依頼一覧
- 確認依頼 detail
- status / requester / approver filter と selected option 復元
- `return_to` による一覧文脈への戻り

これらは確認依頼の閲覧と絞り込みのための導線であり、新しい依頼作成、OK / Cancel、通知、SLA、担当者割当、正式承認 workflow を開始するものではありません。

## 非目標

この first slice では次を変更しません。

- `DocumentApprovalRequest` の DB schema
- status model
- Cancel 理由保存
- 通知、SLA、正式承認 workflow
- requester / approver filter、pagination、return_to、権限境界
- 一覧 / detail UI の redesign
- 他の軽量利用者操作の一括停止

## 関連

- `docs/利用者向け確認依頼runbook.md`
- `docs/正式レビュー承認workflow境界メモ.md`
- `docs/本番運用・インフラ前提.md`
- `app/controllers/document_approval_requests_controller.rb`
- `spec/requests/document_approval_request_maintenance_spec.rb`
