# 生成ファイル再試行と定期ジョブ管理 runbook

この文書は issue `#578` に対応する、`docs-portal` の非同期処理まわりの管理画面運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、次の 3 画面が非同期処理の確認入口です。

- `定期ジョブ`: `admin/recurring_job_schedules`
- `生成ファイルイベント`: `admin/generated_file_events`
- `生成ファイル実行履歴`: `admin/generated_file_runs`

使い分けの基準は次です。

- 定期実行の定義、次回実行、直近実行結果を見たいときは `定期ジョブ`
- 生成処理の元になったイベントの状態を見たいときは `生成ファイルイベント`
- 実際に enqueue された生成ジョブの結果や再実行を見たいときは `生成ファイル実行履歴`

## 2. 最初の切り分け順

1. 定期起点の不具合か、単発の生成失敗かを切り分ける
2. 定期実行そのものが動いていないなら `定期ジョブ` を見る
3. 生成依頼が拾われていない、または dispatch 前後で止まっていそうなら `生成ファイルイベント` を見る
4. 実際の生成ジョブが失敗した、または retry の履歴を追いたいなら `生成ファイル実行履歴` を見る

## 3. 定期ジョブ

`定期ジョブ` 画面では、`recurring_job_schedules` に登録された定義を一覧できます。index では少なくとも次を確認します。

- `ジョブキー`
- `状態`
- `間隔`
- `次回実行`
- `前回enqueue`
- `前回開始`
- `前回終了`
- `前回状態`

一覧には `定義を同期` があり、未登録の定義を dispatcher 実行時に自動登録する current implementation を前提にしています。

詳細画面では次を追加で見ます。

- `ジョブクラス`
- `キュー`
- `重複実行`
- `即時実行要求`
- `前回エラー`
- `引数`
- `実行履歴`

`即時実行を要求` は `run_requested_at` を更新し、`RecurringJobDispatcherJob` を enqueue します。用途は「定期設定や関連データを待たずに、この定義を一度早めに走らせたいとき」です。定義そのものの修正や手作業での個別ジョブ再実行ではありません。

## 4. 生成ファイルイベント

`生成ファイルイベント` は、生成処理の入口になった event を確認する画面です。controller では status / operation / event_source / path / scheduled_at で絞り込みできます。

この画面を先に見る場面:

- 生成対象の変更が入ったはずなのに、実行履歴へ進んでいない
- どの event source から失敗が出ているかを見たい
- path や scheduled time を手掛かりに pending / failed を洗いたい

詳細画面では、その event に関連づいた直近の `GeneratedFileRun` を最大 10 件たどれます。

一覧の `イベントID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / operation / event_source / path / scheduled date の filter、page / per_page を付けた一覧から入った場合でも、detail の `一覧へ戻る` は同じ条件の一覧へ戻ります。detail で `再dispatch` を実行したあとも同じ detail に戻り、`一覧へ戻る` の戻り先は保持されます。

再試行導線は 2 種類あります。

- member の `retry_dispatch`: 対象 event 1 件の `status` を `pending` に戻し、`scheduled_at` を現在時刻へ寄せ、`error_message` と `processed_at` をクリアしたうえで `GeneratedFileEventDispatchJob` を enqueue します
- collection の `retry_failed`: 現在の filter を適用した failed event を古い順に最大 100 件まで同じように `pending` へ戻し、対象が 1 件以上あるときだけ `GeneratedFileEventDispatchJob` を enqueue します

ここでの再試行は「event をもう一度 dispatch キューへ戻す」操作です。すでに生成ジョブ自体が失敗しているケースの再実行は、次の `生成ファイル実行履歴` 側で扱います。

## 5. 生成ファイル実行履歴

`生成ファイル実行履歴` は、実際に enqueue された `GeneratedFileJob` 系の run を確認する画面です。controller では status / job_id / generator / output_writer / event_source / created_at で絞り込みできます。

この画面を先に見る場面:

- 生成ジョブが失敗した後の再実行を判断したい
- 同じ run の retry 親子関係を見たい
- event から dispatch された後、どの generator / output writer で失敗したかを追いたい

詳細画面では次を確認できます。

- 関連する `generated_file_event_public_ids`
- `retry_of_generated_file_run_public_id`
- その run を親とする retry child runs

一覧の `実行ID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / job_id / generator / output_writer / event_source / created date による絞り込みや page / per_page を保ったまま detail へ入り、`一覧へ戻る` で同じ一覧条件へ戻れます。detail で `再実行` を実行したあとも同じ detail に戻るため、再実行前に見ていた一覧条件を失わずに続きの確認ができます。

再試行導線は 2 種類あります。

- member の `retry_run`: 対象 run の `changed_files` と `job_id` を使って `GeneratedFileJob` を再 enqueue します
- collection の `retry_failed`: 現在の filter を適用した failed run を古い順に最大 100 件まで再 enqueue します

retry metadata には `retry_of_generated_file_run_public_id`、`retry_requested_at`、`retry_requested_by_user_id`、bulk 時の `bulk_retry` が入るため、詳細画面では親 run と子 run の関係を追えます。

## 6. event 再dispatch と run 再実行の違い

迷ったときは、どこで失敗しているかで選びます。

- event 再dispatchを使う: 変更イベントはあるが dispatch し直したい、または `GeneratedFileEvent` 側の pending / failed を戻したいとき
- run 再実行を使う: すでに `GeneratedFileRun` が作られており、実際の生成ジョブをもう一度流したいとき

言い換えると、event は「生成依頼の入口」、run は「実際の生成処理」です。両方の画面を行き来できるよう、event 詳細から related runs、run 詳細から related event public IDs を確認します。

## 7. bulk retry を使うときの見方

event / run の `retry_failed` はどちらも current filter を前提に、古い順で最大 100 件まで処理します。まとめて流す前に、少なくとも次を確認します。

- status 以外の filter が残っていないか
- event source / generator / output writer の切り分けが意図どおりか
- path や created/scheduled time の範囲が広すぎないか

この runbook では current implementation の説明に留め、運用上の承認ルールや retry 回数ポリシーまでは新設しません。

## 8. 自動リトライを検討する前に

手動の event 再dispatch / run 再実行を超えて自動リトライを入れる場合は、[自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md) で対象処理ごとの冪等性、二重実行リスク、必要な guard を確認します。

この runbook の retry 導線は現時点では手動運用の説明です。自動化する場合も、import / build / mail / webhook をまとめた基盤 issue ではなく、対象処理 1 つ単位の issue に分けます。

## 9. 関連文書

- [監視・アラート設計](./監視・アラート設計.md)
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
