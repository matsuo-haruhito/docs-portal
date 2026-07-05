# 外部送付履歴 maintenance mode 境界

このメモは、`READ_ONLY_MAINTENANCE` 中の外部送付履歴操作を、read-only 確認と状態変更に分けて読むための運用境界です。

## current support

`READ_ONLY_MAINTENANCE` が有効なとき、外部送付履歴の変更系操作は停止します。

停止する操作:

- `DocumentDeliveryLogsController#create`
  - 文書または文書セットからの送付下書き作成
- `DocumentDeliveryLogsController#update`
  - `送付済みにする`
  - `送付失敗として記録`

停止時は `DocumentDeliveryLog` の作成、`status` 更新、`sent_at` 更新、`error_message` 更新を開始しません。利用者には、メンテナンス中のため下書き作成と手動状態更新を停止していることを alert で表示します。

## read-only に残すもの

maintenance mode 中も、次の確認は継続します。

- `GET /document_delivery_logs`
- 送付履歴一覧の検索 / filter / pagination
- CSV export
- `GET /document_delivery_logs/:public_id`
- detail の `mailto:` URL 確認
- `GET /document_delivery_logs/failure_alert_handoff`

これらは既存の送付履歴を読むための導線であり、下書き作成や手動状態更新とは分けて扱います。`メーラーを開く` は mailto への引き継ぎであり、アプリ側の送付履歴状態を変更しません。

## maintenance mode OFF

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり次の操作を許可します。

- 文書または文書セットからの送付下書き作成
- draft log の `送付済み` 記録
- draft log の `送付失敗` 記録
- filter 付き一覧から詳細へ入った場合の `return_to` 維持

## 非目標

この boundary では次を扱いません。

- メール送信や通知 channel の実装
- 再送 queue / retry policy / ack workflow の追加
- failure handoff payload の仕様変更
- CSV schema / metadata schema の変更
- `DocumentDeliveryLog` status model の再設計
- 宛先 validation、認可 / visible scope、detail redesign の変更
- production infra 側 maintenance page

## 確認観点

- maintenance mode ON で送付下書きが保存されない
- maintenance mode ON で `送付済みにする` が `status` / `sent_at` を更新しない
- maintenance mode ON で `送付失敗として記録` が `status` / `error_message` を更新しない
- maintenance mode ON でも一覧、detail、CSV、failure handoff、mailto の read-only 確認が続く
- maintenance mode OFF の既存作成 / 手動状態更新 flow は壊れていない
