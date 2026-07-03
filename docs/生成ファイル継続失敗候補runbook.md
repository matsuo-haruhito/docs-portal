# 生成ファイル継続失敗候補 runbook

この runbook は、管理ダッシュボードの `運用失敗入口` に表示される生成ファイル継続失敗候補の読み方をまとめる。`GeneratedFiles::RunFailureAlertCandidates`、`GeneratedFiles::RunFailureAlertHandoff`、`Admin::DashboardController`、`Admin::GeneratedFileRunsController#failure_alert_handoff` の current behavior を正本にし、通知 channel、alert rule、自動 retry はここでは定義しない。

## 判定分類

- code-ahead-of-docs
- docs-stale
- docs-sync

## Source of truth

- `app/controllers/admin/dashboard_controller.rb`
- `app/controllers/admin/generated_file_runs_controller.rb`
- `app/services/generated_files/run_failure_alert_candidates.rb`
- `app/services/generated_files/run_failure_alert_handoff.rb`
- `app/views/admin/dashboard/index.html.slim`
- `app/views/admin/generated_file_runs/failure_alert_handoff.html.erb`
- `app/views/admin/generated_file_runs/index.html.erb`
- `spec/requests/admin_dashboard_spec.rb`
- `spec/requests/admin_dashboard_failure_candidate_links_spec.rb`
- `spec/requests/admin_dashboard_generated_file_failure_digest_spec.rb`
- `spec/requests/admin_generated_file_run_failure_alert_handoff_spec.rb`
- `spec/services/generated_files/run_failure_alert_candidates_spec.rb`
- `spec/services/generated_files/run_failure_alert_handoff_spec.rb`
- `spec/services/generated_files/run_failure_alert_handoff_markdown_spec.rb`

## いつ見るか

- 管理ダッシュボードの `生成ファイル` card に `継続失敗候補` が表示されたとき
- 保存済み failed 件数と、同じ identity の連続失敗候補を分けて確認したいとき
- 生成ファイル実行履歴へ進む前に、どの identity から見るべきかを絞りたいとき
- 通知送信なしで、運用引き継ぎ用の HTML / JSON handoff payload を確認したいとき

## Current support

管理ダッシュボードでは、生成ファイル card に `GeneratedFiles::RunFailureAlertCandidates` の候補を read-only に表示する。

current dashboard の呼び出し条件は次のとおり。

- `limit: 5`
- `lookback_limit: 200`
- service default threshold は 3 回以上の連続 failed
- identity は `job_id` / `generator` / `output_writer` / `event_source`

候補になるのは、同じ identity の最新 run から見て failed が threshold 以上連続している場合だけ。後続に success がある古い failed streak は候補として表示しない。

表示される主な情報は次のとおり。

- 候補数
- `job_id`
- `generator` / `output_writer` / `event_source`
- 連続失敗数
- 最終失敗時刻
- 短い error message 断片
- 候補ごとの `この候補の failed 実行履歴` link
- 候補一覧の下に出る `継続失敗候補の failed 実行履歴をすべて見る` link
- `Markdown digest preview` の read-only textarea

`この候補の failed 実行履歴` は、`status=failed` に加えて候補の `job_id`、`generator`、`output_writer`、`event_source` のうち空でない identity component を付けた `admin_generated_file_runs_path` へ進む。特定候補の最新連続失敗を調べるときは、まずこの link から入り、実行履歴側で detail を開く。

`継続失敗候補の failed 実行履歴をすべて見る` は `admin_generated_file_runs_path(status: "failed")` へ戻る広い入口。候補 identity を問わず failed run 全体を見直したいときの補助であり、候補別 link の代替ではない。

`Markdown digest preview` は、admin 内で候補を人間へ引き継ぐための read-only preview。候補 identity、連続失敗数、最終失敗時刻、短い error preview、候補別 failed run path、runbook path だけを含める。通知済み、ack、SLA、自動 retry の状態としては扱わない。

## Admin handoff 画面 / JSON

`/admin/generated_file_runs/failure_alert_handoff` は、生成ファイル実行履歴から開ける read-only handoff 画面。dashboard と同じ bounded window で、最新 run が連続 failed の候補だけを HTML で確認する。

画面上の `JSON` link は同じ候補を `application/json` として返す。JSON は候補数、候補配列、failed 実行履歴への path、runbook path、`read_only: true`、`non_goals: [notification, ack, escalation, retry]` を含む。これは運用引き継ぎや dry-run 確認用であり、外部送信済み payload、通知済み証跡、ack 済み証跡、自動 retry 実行結果ではない。

画面には候補ごとに、identity label、連続失敗数、`last_failed_at`、候補で絞った failed 実行履歴 path、runbook path、`latest_error_message` preview が出る。error preview は service 側の masking / truncate を通した短い確認用断片として扱い、完全な原因調査や raw error の保存先として扱わない。

候補 0 件の場合は、画面にも JSON にも「現在の bounded 抽出条件で handoff payload に載せる対象がない」状態として出る。この状態は、生成ファイル全体の正常保証、保存済み failed 件数 0、通知済み、ack 済み、自動 retry 済み、外部監視 green を意味しない。失敗が気になる場合は `failed` 実行履歴へ戻って個別に確認する。

## Alert handoff payload

`GeneratedFiles::RunFailureAlertHandoff` は、同じ候補抽出を通知前の handoff payload として取り出すための read-only service。候補の identity、連続失敗数、最終失敗時刻、短い error message preview、failed 実行履歴への確認 path、runbook path を返す。

handoff payload は、通知 channel 実装前に人間または運用 script が候補を確認するための artifact として扱う。外部送信済み、alert rule 確定、通知済み状態、ack / escalation、自動 retry の記録ではない。

caller は `RunFailureAlertCandidates` と同じように relation、threshold、limit、lookback_limit を渡せる。dashboard と同じ見方に寄せる場合は `limit: 5` / `lookback_limit: 200` を使い、より狭い dry-run では対象 relation や threshold を呼び出し側で明示する。

`GeneratedFiles::RunFailureAlertHandoff.markdown(entries)` は、dashboard preview と同じ Markdown digest を生成する。error message は複数行を squish し、長すぎる内容を truncate し、token-like value や private path らしい値をそのまま出さない。完全な error detail は生成ファイル実行履歴 detail で確認する。

候補 0 件の場合、handoff payload は空配列になり、Markdown digest は「現在の抽出条件で通知前に渡す対象はない」と表示する。この状態は「本番通知が正常」や「外部監視が green」を意味せず、現在の候補抽出条件で通知前に渡す対象がない、という読み方に留める。

## 読み分け

- 保存済み failed 件数は、生成ファイル実行履歴と生成ファイルイベント履歴の failed 件数 summary。
- 継続失敗候補は、最新 run が同じ identity で連続 failed しているもの。
- 候補ごとの link は空でない identity component だけを query に含める。空の `output_writer` などは条件に載せず、不要な空文字 filter として扱わない。
- 候補別 link で絞っても、原因調査は実行履歴 detail、error message、関連 runbook を合わせて進める。dashboard card だけで根本原因や retry 可否を確定しない。
- `Markdown digest preview`、admin handoff HTML、handoff JSON は候補の引き継ぎ用であり、通知送信や ack / escalation の記録ではない。
- `最新の対象履歴` は対象履歴の `updated_at` 最大値であり、alert 発火時刻や最終失敗時刻そのものではない。
- `古い失敗のみ` が出る場合は、最近の障害ではなく古い未解消履歴が残っている可能性がある。
- error message 断片は調査入口の preview であり、完全な原因調査は生成ファイル実行履歴 detail や関連 runbook へ進んで行う。

## Current support として書かないこと

- 通知 channel や外部監視サービスへ自動送信される、とは書かない
- dashboard や handoff 画面から自動 retry できる、とは書かない
- alert rule の本番閾値が確定した、とは書かない
- handoff payload が通知済み、ack 済み、再通知抑制済みである、とは書かない
- Webhook / Git 同期 / 外部フォルダ同期にも同じ candidate 表示が横展開済み、とは書かない
- `lookback_limit: 200` の外にある全履歴を dashboard や handoff 画面が網羅する、とは書かない

## 迷ったときの確認順

1. dashboard の `生成ファイル` card で保存済み failed 件数と継続失敗候補を分けて読む
2. まず候補ごとの `この候補の failed 実行履歴` から、同じ identity の failed run へ進む
3. 候補をまたいで見る必要があるときだけ、`継続失敗候補の failed 実行履歴をすべて見る` で failed run 全体へ広げる
4. identity、最終失敗時刻、error message 断片を手がかりに詳細を確認する
5. 通知前の dry-run や admin 内の引き継ぎが必要な場合は `Markdown digest preview`、`継続失敗候補 handoff` 画面 / JSON、または `GeneratedFiles::RunFailureAlertHandoff` の payload を確認する
6. retry や定期ジョブ側の確認が必要なら `docs/生成ファイル再試行と定期ジョブ管理runbook.md` に戻る
7. 自動 retry の可否を検討する場合は `docs/自動リトライ安全性棚卸し.md` を先に確認する

## 将来の通知 channel で別途決めること

- 通知先と宛先管理
- 本番 alert rule の threshold / limit / lookback_limit
- 通知済み重複抑制と再通知間隔
- ack / escalation policy
- 外部監視サービス、Slack、mail、webhook などへの実送信方法
- 通知後に自動 retry へ進めるか、人間確認を必須にするか

## 関連

- Closes #2756
- Related runtime: #2755 / PR #2762
- Related handoff payload: #2809
- Related UI link follow-up: #2840 / PR #2852
- Related digest preview: #3676
- Related admin handoff preview: #2892 / PR #4302
- Related docs sync: #4303
- [監視・アラート設計](./監視・アラート設計.md)
- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)
- [生成ファイル再試行と定期ジョブ管理runbook](./生成ファイル再試行と定期ジョブ管理runbook.md)
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md)
