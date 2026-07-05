# 外部フォルダ同期 webhook maintenance-mode 境界

## 目的

外部フォルダ同期の provider webhook 入口は、Google Drive / SharePoint からの変更通知を受け、`ExternalFolderSyncWebhookEvent` として記録したうえで同期 job を enqueue する入口です。

`READ_ONLY_MAINTENANCE` 中は、provider が期待する応答と運用上の event 記録は維持しつつ、新しい同期処理の開始だけを止めます。

## maintenance mode 中に止めるもの

- Google Drive webhook 受信後の `ExternalFolderSyncWebhookEventJob.perform_later`
- SharePoint notification 受信後の `ExternalFolderSyncWebhookEventJob.perform_later`

これにより、maintenance mode 中に受けた変更通知から外部フォルダ同期 runner / apply 相当の処理を開始しません。

## maintenance mode 中も残すもの

- Google Drive webhook への `200 OK` 応答
- SharePoint `validationToken` への `text/plain` 応答
- SharePoint notification への `202 Accepted` 応答
- `ExternalFolderSyncWebhookEvent` の記録
- provider verification failure / source unavailable / duplicate event key の既存境界
- header / payload の secret masking

provider 側の challenge response や acknowledgement を壊すと subscription 維持に影響するため、maintenance mode は webhook 受信自体を拒否するものではありません。

## 非目標

- Google Drive / SharePoint subscription policy の変更
- OAuth / token refresh / credential policy の変更
- provider webhook 署名・検証方式の大規模変更
- 外部フォルダ同期 source の dry-run / apply / enqueue / subscribe / unsubscribe の停止判断
- 外部フォルダ同期 runner 本体、provider API contract、DB schema の変更
- 全外部連携停止 policy の確定

## 確認観点

- maintenance mode ON で、受信 event は記録されるが sync job は enqueue されない
- maintenance mode ON でも SharePoint validation token は従来どおり返る
- maintenance mode OFF の既存 webhook 受信・event 記録・enqueue は既存 request spec で維持する
