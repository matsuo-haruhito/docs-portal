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

未登録 0 件と filter あり 0 件は読み分けます。

- filter なしで 0 件の場合は、登録済み定期ジョブがまだない状態です。まず空状態説明と `定義を同期` を確認し、dispatcher 定義に基づいて登録する入口として扱います。
- 前回状態、有効状態、検索条件がある状態で 0 件の場合は、未登録ではなく条件不一致です。`絞り込み解除` で条件を外すか、条件値を見直してから再確認します。
- 表示設定 editor は、行がある場合の列表示補助です。定義の登録、filter 条件、dispatcher 実行、job retry の意味は変えません。

一覧は `rails_table_preferences` 対応済みです。`admin_recurring_job_schedules` の表示設定では、`ジョブキー`、`状態`、`間隔`、`次回実行`、`前回enqueue`、`前回開始`、`前回終了`、`前回状態`、`操作` の列を調整できます。`ジョブキー` と `操作` は pin された列として扱われます。

表示設定を使うときの目安:

- 障害 triage では `ジョブキー`、`前回状態`、`前回終了`、`操作` を残すと、詳細画面へ進む対象を見つけやすい
- 実行間隔や次回予定を見たいときは `間隔` と `次回実行` を残す
- `前回enqueue`、`前回開始`、`前回終了` は、dispatcher が拾ったか、実行が開始したか、完了まで進んだかを分けて読むための列として扱う
- 未登録 0 件では、列表示設定より先に空状態説明と `定義を同期` の読み方を確認する。表示設定は schedule 行が登録された後に使う
- filter あり 0 件では、表示設定で列を増やしても条件不一致は解消しない。前回状態、有効状態、検索語を見直すか `絞り込み解除` を使う
- 表示設定は列の見え方を変えるだけで、`定義を同期`、前回状態 filter、Triage対象 counts、詳細リンクの `return_to` は変えない

一覧の検索欄では、`job_key`、`job_class`、`queue_name`、`last_error_message` の断片を部分一致で検索できます。検索語は前後の空白を落としてから最大 100 文字まで適用され、前回状態 filter と併用できます。

検索を使うときの目安:

- 手元に `job_key` や `job_class` が残っている場合は、定期実行の定義そのものを探す入口として使う
- queue 名や前回エラー断片から探す場合も、対象は schedule の一覧と直近状態に閉じる
- 長い error log 全文を貼るのではなく、特徴的なエラー断片を 100 文字以内で指定する
- `ActiveJob ID` や個別 run の古いエラーを探す画面ではありません。実行履歴の状態や詳細は、対象 schedule の詳細画面で 50 件ずつ確認します
- 生成対象 event の path や `gfr...` の実行IDから探す場合は、`生成ファイルイベント` または `生成ファイル実行履歴` の検索を使います

詳細画面では次を追加で見ます。

- `ジョブクラス`
- `キュー`
- `重複実行`
- `即時実行要求`
- `前回エラー`
- `引数`
- `実行履歴`

`実行履歴` は 50 件ずつ表示され、必要に応じて前後のページへ移動できます。初期表示はこれまでと同じ 50 件入口です。古い run を追う場合は、状態、`ActiveJob ID / エラー`、予定時刻 filter で対象を絞り、表示範囲と全件数を見ながら過去ページへ進みます。履歴の `状態` filter は詳細画面内の run 表示にだけ効き、一覧側の前回状態 filter や検索欄とは役割が異なります。

実行履歴では `予定時刻(開始)` / `予定時刻(終了)` でも絞り込めます。date-only の `YYYY-MM-DD` を入れた場合、開始側はその日の beginning of day、終了側は end of day として扱われます。日時まで指定した場合は、その日時を境界として扱います。

予定時刻 filter を使う場面:

- ある時間帯に dispatcher が拾ったはずの run を切り分けたい
- 状態 filter や `ActiveJob ID / エラー` 検索と組み合わせ、特定の予定時刻範囲に発生した失敗だけを確認したい
- `次回実行` や `前回enqueue` の時刻から、対象 schedule の詳細履歴へ戻って確認したい

実行履歴の page 移動では、`run_status`、`q`、`scheduled_from`、`scheduled_to`、`return_to`、`per_page` が維持されます。表示件数は 50 件または 100 件を選べますが、全件一括表示ではありません。page が範囲外の場合は、存在する最後のページへ丸めて表示されます。

予定時刻に不正な入力がある場合、詳細画面には `予定時刻(開始)` または `予定時刻(終了)` の warning が表示され、その条件だけが適用されません。片方だけ有効な日時条件がある場合は、有効な条件だけで絞り込まれます。warning が出ている状態で 0 件になった場合は、状態・検索語・予定時刻を見直すか、`絞り込み解除` で履歴の先頭ページへ戻ってから再確認します。

`即時実行を要求` は `run_requested_at` を更新し、`RecurringJobDispatcherJob` を enqueue します。用途は「定期設定や関連データを待たずに、この定義を一度早めに走らせたいとき」です。定義そのものの修正や手作業での個別ジョブ再実行ではありません。

## 4. 生成ファイルイベント

`生成ファイルイベント` は、生成処理の入口になった event を確認する画面です。controller では status / operation / event_source / path / q / scheduled_at で絞り込みできます。

検索欄 `イベントID / パス / エラー` は first slice として、`GeneratedFileEvent.public_id`、path、`error_message` を部分一致で検索します。path 検索では Windows 区切り文字 `\\` を `/` として扱います。

専用の `パスを含む` filter と `q` の使い分けは次です。

- `パスを含む`: path だけを対象に、生成対象の場所から event を絞る
- `イベントID / パス / エラー`: 手元に残った event ID、path 断片、error message 断片から横断的に探す
- どちらも status / operation / event_source / scheduled date filter と AND 条件で併用される

この画面を先に見る場面:

- 生成対象の変更が入ったはずなのに、実行履歴へ進んでいない
- どの event source から失敗が出ているかを見たい
- path や scheduled time を手掛かりに pending / failed を洗いたい
- 手元に残った `gfe...` の event ID、path 断片、error message 断片から対象 event を探したい

一覧は `rails_table_preferences` 対応済みです。`admin_generated_file_events` の表示設定では、`イベントID`、`状態`、`パス`、`操作種別`、`発生元`、`エラー`、`回数`、`実行予定`、`処理完了`、`操作` の列を調整できます。

表示設定を使うときの目安:

- dispatch 前後の詰まりを見るときは `イベントID`、`状態`、`パス`、`発生元`、`実行予定`、`操作` を残す
- 失敗調査では `エラー` と `回数` を残すと、同じ event の再発や一括再dispatch対象を読みやすい
- 表示設定は列の見え方だけを変え、filter、検索条件、再dispatch対象、status counts は変えない

詳細画面では、その event に関連づいた直近の `GeneratedFileRun` を最大 10 件たどれます。探索対象は current implementation では生成ファイル実行履歴の最新 200 件です。関連 run が見えない場合は、対象 event の public ID を `GeneratedFileRun.metadata.generated_file_event_public_ids` に持つ run が最新 200 件の外に出ている可能性があります。

一覧の `イベントID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / operation / event_source / path / q / scheduled date の filter、page / per_page を付けた一覧から入った場合でも、detail の `一覧へ戻る` は同じ条件の一覧へ戻ります。detail で `再dispatch` を実行したあとも同じ detail に戻り、`一覧へ戻る` の戻り先は保持されます。

再試行導線は 2 種類あります。

- member の `retry_dispatch`: 対象 event 1 件の `status` を `pending` に戻し、`scheduled_at` を現在時刻へ寄せ、`error_message` と `processed_at` をクリアしたうえで `GeneratedFileEventDispatchJob` を enqueue します
- collection の `retry_failed`: 現在の filter を適用した failed event を古い順に最大 100 件まで同じように `pending` へ戻し、対象が 1 件以上あるときだけ `GeneratedFileEventDispatchJob` を enqueue します

ここでの再試行は「event をもう一度 dispatch キューへ戻す」操作です。すでに生成ジョブ自体が失敗しているケースの再実行は、次の `生成ファイル実行履歴` 側で扱います。

## 5. 生成ファイル実行履歴

`生成ファイル実行履歴` は、実際に enqueue された `GeneratedFileJob` 系の run を確認する画面です。controller では status / job_id / generator / output_writer / event_source / created_at に加えて、実行ID、パス、エラー、補助メタデータの断片で絞り込みできます。

この画面を先に見る場面:

- 生成ジョブが失敗した後の再実行を判断したい
- 同じ run の retry 親子関係を見たい
- event から dispatch された後、どの generator / output writer で失敗したかを追いたい
- 手元に残った `gfr...` の実行ID、入力パス、変更ファイル、生成パス、エラー断片、run metadata のID断片から対象 run を探したい

検索欄 `実行ID / パス / エラー / メタデータ` は first slice として、`GeneratedFileRun.public_id`、`source_paths`、`changed_files`、`generated_paths`、`error_message`、`metadata` の文字列表現を部分一致で検索します。関連イベントを探す場合は、GeneratedFileEvent 側の path や本文を横断検索するのではなく、run metadata に残っている `generated_file_event_public_ids` などのID断片を手掛かりにします。

検索条件は status / job_id / generator / output_writer / event_source / created date filter と併用できます。検索 0 件の場合は、通常の未登録状態ではなく「条件に一致する生成ファイル実行履歴はありません。」と表示されます。

詳細画面では次を確認できます。

- 関連する `generated_file_event_public_ids`
- `retry_of_generated_file_run_public_id`
- その run を親とする retry child runs

一覧の `実行ID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / job_id / generator / output_writer / event_source / created date / 実行ID・パス・エラー・メタデータ断片による絞り込みや page / per_page を保ったまま detail へ入り、`一覧へ戻る` で同じ一覧条件へ戻れます。detail で `再実行` を実行したあとも同じ detail に戻るため、再実行前に見ていた一覧条件を失わずに続きの確認ができます。

関連イベント、再実行元、派生した再実行のリンクも、detail に渡された安全化済み `return_to` を引き継ぎます。絞り込み済みの `生成ファイル実行履歴` 一覧から detail に入り、関連イベントや親子 run をたどったあとでも、各 detail の `一覧へ戻る` は元の status / generator / page / per_page / q などを含む一覧文脈へ戻るための導線として読みます。unsafe な `return_to` は既存の fallback 境界で通常の一覧 URL に戻され、関連リンク経由で外部 URL や protocol-relative URL を広げる用途には使いません。

再試行導線は 2 種類あります。

- member の `retry_run`: 対象 run の `changed_files` と `job_id` を使って `GeneratedFileJob` を再 enqueue します
- collection の `retry_failed`: 現在の filter を適用した failed run を古い順に最大 100 件まで再 enqueue します

retry metadata には `retry_of_generated_file_run_public_id`、`retry_requested_at`、`retry_requested_by_user_id`、bulk 時の `bulk_retry` が入るため、詳細画面では親 run と子 run の関係を追えます。

自動リトライの first slice は、`ai_usecase_decision_flow` の `filesystem` writer が failed になった run だけを対象にします。`document_version` writer、import、mail、webhook、手動 retry / bulk retry で作られた child run は自動 retry の対象外です。自動 retry は parent run 1 件につき 1 回までで、metadata には `retry_of_generated_file_run_public_id`、`retry_requested_at`、`retry_requested_by_user_id: nil`、`auto_retry: true`、`retry_reason` が入ります。enqueue には既存の `GeneratedFileJob` と同じ `job_id` / `changed_files` を使うため、既存 concurrency key の範囲内で扱います。

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
- event 側で `イベントID / パス / エラー` 検索を使っている場合、意図した failed event だけに絞れているか
- run 側で実行ID・パス・エラー・メタデータ検索を使っている場合、意図した failed run だけに絞れているか

日時 filter に不正な入力がある場合、一覧には「日時フィルタを確認してください。」という warning が表示され、その日時条件が適用されなかったことが分かります。warning が出ている状態では、bulk retry 前に日付入力を直すか、意図して外した条件だけが残っているかを確認します。

この runbook では current implementation の説明に留め、運用上の承認ルールや retry 回数ポリシーまでは新設しません。

## 8. 自動リトライを検討する前に

手動の event 再dispatch / run 再実行を超えて自動リトライを入れる場合は、[自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md) で対象処理ごとの冪等性、二重実行リスク、必要な guard を確認します。

この runbook の retry 導線は現時点では手動運用の説明です。自動化する場合も、import / build / mail / webhook をまとめた基盤 issue ではなく、対象処理 1 つ単位の issue に分けます。

## 9. 関連文書

- [監視・アラート設計](./監視・アラート設計.md)
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
