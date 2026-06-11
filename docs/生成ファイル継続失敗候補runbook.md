# 生成ファイル継続失敗候補 runbook

この runbook は、管理ダッシュボードの `運用失敗入口` に表示される生成ファイル継続失敗候補の読み方をまとめる。`GeneratedFiles::RunFailureAlertCandidates` と `Admin::DashboardController` の current behavior を正本にし、通知 channel、alert rule、自動 retry はここでは定義しない。

## 判定分類

- code-ahead-of-docs
- docs-stale
- docs-sync

## Source of truth

- `app/controllers/admin/dashboard_controller.rb`
- `app/services/generated_files/run_failure_alert_candidates.rb`
- `app/views/admin/dashboard/index.html.slim`
- `spec/requests/admin_dashboard_spec.rb`
- `spec/services/generated_files/run_failure_alert_candidates_spec.rb`

## いつ見るか

- 管理ダッシュボードの `生成ファイル` card に `継続失敗候補` が表示されたとき
- 保存済み failed 件数と、同じ identity の連続失敗候補を分けて確認したいとき
- 生成ファイル実行履歴へ進む前に、どの identity から見るべきかを絞りたいとき

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
- `継続失敗候補の failed 実行履歴` link

`継続失敗候補の failed 実行履歴` は `admin_generated_file_runs_path(status: "failed")` へ戻る入口であり、候補 identity だけに絞る専用検索ではない。

## 読み分け

- 保存済み failed 件数は、生成ファイル実行履歴と生成ファイルイベント履歴の failed 件数 summary。
- 継続失敗候補は、最新 run が同じ identity で連続 failed しているもの。
- `最新の対象履歴` は対象履歴の `updated_at` 最大値であり、alert 発火時刻や最終失敗時刻そのものではない。
- `古い失敗のみ` が出る場合は、最近の障害ではなく古い未解消履歴が残っている可能性がある。
- error message 断片は調査入口の preview であり、完全な原因調査は生成ファイル実行履歴 detail や関連 runbook へ進んで行う。

## Current support として書かないこと

- 通知 channel や外部監視サービスへ自動送信される、とは書かない
- dashboard から自動 retry できる、とは書かない
- alert rule の本番閾値が確定した、とは書かない
- Webhook / Git 同期 / 外部フォルダ同期にも同じ candidate 表示が横展開済み、とは書かない
- `lookback_limit: 200` の外にある全履歴を dashboard が網羅する、とは書かない

## 迷ったときの確認順

1. dashboard の `生成ファイル` card で保存済み failed 件数と継続失敗候補を分けて読む
2. `継続失敗候補の failed 実行履歴` から生成ファイル実行履歴へ進む
3. identity、最終失敗時刻、error message 断片を手がかりに詳細を確認する
4. retry や定期ジョブ側の確認が必要なら `docs/生成ファイル再試行と定期ジョブ管理runbook.md` に戻る
5. 自動 retry の可否を検討する場合は `docs/自動リトライ安全性棚卸し.md` を先に確認する

## 関連

- Closes #2756
- Related runtime: #2755 / PR #2762
- [監視・アラート設計](./監視・アラート設計.md)
- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)
- [生成ファイル再試行と定期ジョブ管理runbook](./生成ファイル再試行と定期ジョブ管理runbook.md)
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md)
