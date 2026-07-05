# Webhook設定 maintenance mode 境界

## 目的

`READ_ONLY_MAINTENANCE` 中に Webhook endpoint の作成・更新・削除だけを停止し、送信履歴の確認や失敗 handoff は read-only に残す境界を整理します。

## current support

- `Admin::WebhookEndpointsController#create` は maintenance mode 中に新しい Webhook endpoint を保存しません。
- `Admin::WebhookEndpointsController#update` は maintenance mode 中に URL、secret、active、event types などの設定を更新しません。
- `Admin::WebhookEndpointsController#destroy` は maintenance mode 中に Webhook endpoint を削除しません。
- 停止時は 500 ではなく、Webhook 設定一覧または編集画面へ alert 付きで戻します。
- Webhook endpoint 一覧、最近の送信履歴、送信履歴詳細、failure alert handoff は maintenance mode 中も read-only に確認できます。

## 非目標

- Webhook 署名方式や secret rotation policy の変更
- Webhook delivery retry / failure handoff の変更
- 通知対象 event model、payload schema、外部 API contract の変更
- DB schema、認可、Webhook 画面全体の redesign
- Webhook 再送操作の maintenance mode 停止

## 確認観点

- maintenance mode ON で create / update / destroy が DB を変更しないこと
- maintenance mode OFF で既存 CRUD と戻り先が維持されること
- maintenance mode ON でも一覧、delivery detail、failure handoff が読めること
- blank secret で既存 secret を維持する既存挙動を壊していないこと

## 関連

- [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
