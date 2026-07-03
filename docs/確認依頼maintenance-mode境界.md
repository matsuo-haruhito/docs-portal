# 確認依頼 maintenance mode 境界

このメモは `DocumentApprovalRequest` のうち、`READ_ONLY_MAINTENANCE` 中に止める操作と、引き続き read-only に確認できる操作を短く整理します。

## current support

`READ_ONLY_MAINTENANCE` が有効なときは、文書詳細からの確認依頼新規作成を停止します。`DocumentApprovalRequestsController#create` は新しい `DocumentApprovalRequest` を保存せず、文書詳細へ戻して、メンテナンス中のため新規作成が停止していることを alert で表示します。

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり確認依頼を作成し、作成後は確認依頼 detail へ進みます。validation error の扱い、requester 設定、approver 指定、文書詳細への戻り先は既存 flow を正本とします。

## read-only に維持するもの

maintenance mode 中でも、次の確認導線は止めません。

- 確認依頼の全体一覧
- 文書配下の確認依頼一覧
- 確認依頼 detail
- status / requester / approver filter と selected option 復元

これらは確認依頼の閲覧と絞り込みのための導線であり、新しい依頼作成、通知、SLA、担当者割当、正式承認 workflow を開始するものではありません。

## 非目標

この first slice では次を変更しません。

- `DocumentApprovalRequest` の DB schema
- status model
- `OK` / `Cancel` の停止境界
- Cancel 理由保存
- 通知、SLA、正式承認 workflow
- requester / approver filter、pagination、return_to、権限境界

`OK` / `Cancel` 停止境界は別 Issue の受け入れ条件で扱い、このメモでは新規作成停止だけを対象にします。

## 関連

- `docs/利用者向け確認依頼runbook.md`
- `docs/本番運用・インフラ前提.md`
- `app/controllers/document_approval_requests_controller.rb`
- `spec/requests/document_approval_request_maintenance_spec.rb`
