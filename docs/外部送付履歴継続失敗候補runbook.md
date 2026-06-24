# 外部送付履歴継続失敗候補 runbook

この runbook は、`DocumentDeliveryLogs::FailureAlertCandidates` と `DocumentDeliveryLogs::FailureAlertHandoff` の current behavior を読むための運用メモです。外部送付履歴の通知 channel、alert rule、自動 retry、ack / escalation はここでは定義しません。

## Source of truth

- `app/services/document_delivery_logs/failure_alert_candidates.rb`
- `app/services/document_delivery_logs/failure_alert_handoff.rb`
- `app/controllers/admin/dashboard_controller.rb`
- `app/views/admin/dashboard/index.html.slim`
- `app/controllers/document_delivery_logs_controller.rb`
- `spec/services/document_delivery_logs/failure_alert_candidates_spec.rb`
- `spec/services/document_delivery_logs/failure_alert_handoff_spec.rb`
- `spec/requests/document_delivery_log_failure_alert_handoff_spec.rb`
- `spec/requests/admin_dashboard_document_delivery_failure_alert_spec.rb`
- `docs/管理ダッシュボード・モデルブラウザ運用runbook.md`
- `docs/外部送付履歴運用runbook.md`
- `docs/監視・アラート設計.md`

## Current support

`DocumentDeliveryLogs::FailureAlertCandidates` は、外部送付履歴の failed log から継続失敗候補を read-only に抽出します。

current default は次のとおりです。

- threshold は 3 回以上の連続 failed
- limit は 20 件
- identity は `project_id` / `delivery_type` / normalized `to_addresses` / squished `subject`
- 並び順は最新の失敗記録が新しい候補から

候補になるのは、同じ identity の最新 log から見て failed が threshold 以上連続している場合だけです。後続に `sent` や `draft` など failed 以外の log がある古い failed streak は候補にしません。

`DocumentDeliveryLogs::FailureAlertHandoff` は、同じ候補を通知前の handoff payload として取り出すための read-only service です。候補の identity、案件 code/name、送付方式、受信者 preview、件名 preview、連続失敗数、最終失敗時刻、短い error message preview、確認用 path、runbook path を返します。

確認用 path は `status=failed`、候補の `delivery_type`、件名を使った `q` を付けた `/document_delivery_logs` です。本文、添付、CC/BCC の full text、外部シークレットは payload に含めません。preview と確認用 path の `q` は `Bearer` / `Basic` credential、`token=`、`secret=` などの secret-like value を `[FILTERED]` に置換してから返します。

管理ダッシュボードの `運用失敗入口` では、外部送付履歴 card に保存済み `failed` 件数と継続失敗候補を分けて表示します。dashboard 表示は `DocumentDeliveryLogs::FailureAlertHandoff` の既存 payload を使い、candidate は最大 5 件、lookback window は最新 200 件に bounded されています。

Dashboard の候補表示で読めるのは、案件 code/name、送付方式、連続失敗数、最終失敗時刻、recipient preview、subject preview、error preview、候補別 failed 一覧 link、failed 一覧全体 link、runbook link です。raw 本文、CC/BCC full text、添付 metadata、secret-like value は表示対象にしません。

Dashboard の候補 0 件は「current 条件で外部送付履歴の handoff 候補がない」ことだけを示します。mail 全体正常、外部監視 green、通知正常、ack 済み、自動 retry 済みを意味しません。

## Dashboard 表示の読み方

`admin/dashboard` の `運用失敗入口` は、保存済み履歴の件数と read-only 調査候補を同じ card 内で分けて見せます。

外部送付履歴 card では次を分けて読む。

- `保存済み履歴`: `DocumentDeliveryLog.failed` の保存済み件数。候補数、通知状態、ack 状態、自動復旧状態ではない
- `継続失敗候補`: 同じ identity の最新履歴が連続 failed のものだけを `FailureAlertHandoff` で抽出した read-only 調査入口
- `この候補の failed 送付履歴`: 候補の `failed_delivery_logs_path` へ戻る link。送付状態変更や retry 実行ではない
- `外部送付履歴の failed 一覧をすべて見る`: `status=failed` の一覧へ戻る link。候補 identity に限らない
- `継続失敗候補 runbook`: この runbook へ戻る link。通知や alert rule の設定画面ではない

Dashboard は first triage の入口です。候補が出た場合も、原因確認は `外部送付履歴運用runbook` に戻り、一覧と詳細で宛先、件名、方式、失敗理由、対象文書または文書セットを確認します。

## JSON endpoint の読み方

`GET /document_delivery_logs/failure_alert_handoff.json` は、internal user が現在の handoff payload を read-only に確認する入口です。HTML 画面、通知送信、ack、自動 retry、送付状態変更は行いません。

JSON response は次の形で読む。

- `generated_at`: payload を生成した時刻
- `count`: current 条件で返された候補数
- `note`: 候補あり / 候補なしの読み方。候補ありの場合も read-only handoff であり、通知や状態変更は行わない。候補なしの場合も正常保証、外部監視 green、通知正常を意味しない
- `runbook_path`: この runbook への参照
- `entries`: `DocumentDeliveryLogs::FailureAlertHandoff` が返す候補 payload の配列

`entries` の各要素は、service payload と同じく identity、案件、送付方式、recipient / subject preview、連続失敗数、最終失敗時刻、error preview、`failed_delivery_logs_path` を持ちます。`recipient_preview`、`subject_preview`、`latest_error_message`、`failed_delivery_logs_path` は secret-like value を mask / truncate した調査入口であり、本文 full text、添付 full metadata、CC/BCC full text、raw token の確認場所として扱いません。

external user はこの endpoint を使えません。candidate が 0 件の JSON は「今の handoff 条件では候補がない」ことだけを示し、送付履歴全体の正常性、外部監視の成功、通知 channel の稼働状態を保証しません。

## 既存 runbook との接続

- Dashboard で候補を見る場合は、[管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md) の `運用失敗入口` を入口にします。保存済み failed 件数と継続失敗候補を別物として読み、candidate 0 件を正常保証として扱いません。
- 監視観点から見る場合は、[監視・アラート設計](./監視・アラート設計.md) の `外部依存監視` と `Runbook との接続` を入口にします。この候補は `mail / webhook の継続失敗` のうち、外部送付履歴側を read-only payload として切り出すための内部補助です。
- 画面で実際に確認する場合は、[外部送付履歴運用runbook](./外部送付履歴運用runbook.md) の検索、状態 filter、方式 filter、詳細確認、手動状態更新の読み方に戻ります。
- 候補 payload、Dashboard 表示、一覧検索、手動状態更新、通知 channel は別のものです。候補 payload と Dashboard 表示は調査入口であり、送付状態の変更や本番 alert 発火を意味しません。
- generated file の継続失敗候補とは identity と確認 path が異なります。生成ファイル側の候補や dashboard 表示を読み返す場合は [生成ファイル継続失敗候補runbook](./生成ファイル継続失敗候補runbook.md) を参照します。

## 読み分け

- `identity` は同じ送付候補をまとめるための内部キーです。受信者や件名の preview は調査入口であり、通知文面や外部公開用の正本ではありません。
- `failure_count` は最新 log から連続している failed 数です。保存済み failed 件数全体ではありません。
- `last_failed_at` は最新 failed log の更新時刻です。外部メーラーの実送信失敗時刻や alert 発火時刻ではありません。
- `failed_delivery_logs_path` は確認入口です。絞り込み後も詳細画面と既存 runbook を合わせて原因を確認します。
- 候補 0 件は、current 条件で handoff する対象がないことだけを意味します。外部監視が green であることや、本番通知が正常であることは意味しません。

## Current support として書かないこと

- 通知 channel や外部監視サービスへ自動送信される、とは書かない
- dashboard の候補表示が alert rule、通知済み状態、ack 状態、自動 retry 状態を示す、とは書かない
- alert rule の本番 threshold / limit / lookback_limit が確定した、とは書かない
- handoff payload が通知済み、ack 済み、再通知抑制済みである、とは書かない
- 自動 retry、bulk retry、再送 queue がある、とは書かない
- 送付状態 machine、承認 workflow、外部メーラー連携を変更した、とは書かない

## 迷ったときの確認順

1. internal admin として管理ダッシュボードの `運用失敗入口` を開き、外部送付履歴 card の保存済み failed 件数と継続失敗候補を分けて確認する
2. 必要なら internal user として `GET /document_delivery_logs/failure_alert_handoff.json` を開き、`count`、`note`、`entries` を read-only に確認する
3. `DocumentDeliveryLogs::FailureAlertHandoff` の payload で candidate の identity、案件、連続失敗数、最終失敗時刻、error preview を確認する
4. `failed_delivery_logs_path` から既存の外部送付履歴一覧へ進む
5. 一覧と詳細で宛先、件名、失敗理由、対象文書または文書セットを確認する
6. 操作や画面の読み方で迷う場合は `docs/外部送付履歴運用runbook.md` に戻る
7. retry、通知先、alert rule、ack / escalation が必要になった場合は、この runbook では決めず別 Issue で仕様判断する

## 関連

- Closes #2990
- Refs #2991
- Refs #3227
- Refs #3732
- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)
- [外部送付履歴運用runbook](./外部送付履歴運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
