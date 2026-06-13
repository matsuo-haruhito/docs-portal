# 外部送付履歴継続失敗候補 runbook

この runbook は、`DocumentDeliveryLogs::FailureAlertCandidates` と `DocumentDeliveryLogs::FailureAlertHandoff` の current behavior を読むための運用メモです。外部送付履歴の通知 channel、alert rule、自動 retry、ack / escalation、dashboard 表示はここでは定義しません。

## Source of truth

- `app/services/document_delivery_logs/failure_alert_candidates.rb`
- `app/services/document_delivery_logs/failure_alert_handoff.rb`
- `spec/services/document_delivery_logs/failure_alert_candidates_spec.rb`
- `spec/services/document_delivery_logs/failure_alert_handoff_spec.rb`
- `docs/外部送付履歴運用runbook.md`

## Current support

`DocumentDeliveryLogs::FailureAlertCandidates` は、外部送付履歴の failed log から継続失敗候補を read-only に抽出します。

current default は次のとおりです。

- threshold は 3 回以上の連続 failed
- limit は 20 件
- identity は `project_id` / `delivery_type` / normalized `to_addresses` / squished `subject`
- 並び順は最新の失敗記録が新しい候補から

候補になるのは、同じ identity の最新 log から見て failed が threshold 以上連続している場合だけです。後続に `sent` や `draft` など failed 以外の log がある古い failed streak は候補にしません。

`DocumentDeliveryLogs::FailureAlertHandoff` は、同じ候補を通知前の handoff payload として取り出すための read-only service です。候補の identity、案件 code/name、送付方式、受信者 preview、件名 preview、連続失敗数、最終失敗時刻、短い error message preview、確認用 path、runbook path を返します。

確認用 path は `status=failed`、候補の `delivery_type`、件名を使った `q` を付けた `/document_delivery_logs` です。本文、添付、CC/BCC の full text、外部シークレットは payload に含めません。

## 読み分け

- `identity` は同じ送付候補をまとめるための内部キーです。受信者や件名の preview は調査入口であり、通知文面や外部公開用の正本ではありません。
- `failure_count` は最新 log から連続している failed 数です。保存済み failed 件数全体ではありません。
- `last_failed_at` は最新 failed log の更新時刻です。外部メーラーの実送信失敗時刻や alert 発火時刻ではありません。
- `failed_delivery_logs_path` は確認入口です。絞り込み後も詳細画面と既存 runbook を合わせて原因を確認します。
- 候補 0 件は、current 条件で handoff する対象がないことだけを意味します。外部監視が green であることや、本番通知が正常であることは意味しません。

## Current support として書かないこと

- 通知 channel や外部監視サービスへ自動送信される、とは書かない
- dashboard に継続失敗候補が表示される、とは書かない
- alert rule の本番 threshold / limit / lookback_limit が確定した、とは書かない
- handoff payload が通知済み、ack 済み、再通知抑制済みである、とは書かない
- 自動 retry、bulk retry、再送 queue がある、とは書かない
- 送付状態 machine、承認 workflow、外部メーラー連携を変更した、とは書かない

## 迷ったときの確認順

1. `DocumentDeliveryLogs::FailureAlertHandoff` の payload で candidate の identity、案件、連続失敗数、最終失敗時刻、error preview を確認する
2. `failed_delivery_logs_path` から既存の外部送付履歴一覧へ進む
3. 一覧と詳細で宛先、件名、失敗理由、対象文書または文書セットを確認する
4. 操作や画面の読み方で迷う場合は `docs/外部送付履歴運用runbook.md` に戻る
5. retry、通知先、alert rule、ack / escalation が必要になった場合は、この runbook では決めず別 Issue で仕様判断する

## 関連

- Closes #2990
- [外部送付履歴運用runbook](./外部送付履歴運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
