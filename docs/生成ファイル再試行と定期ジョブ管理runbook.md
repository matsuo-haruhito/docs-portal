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
- 実際に enqueue された生成ジョブの結果や再実行を見たいなら `生成ファイル実行履歴`

## 2. 最初の切り分け順

1. 定期起点の不具合か、単発の生成失敗かを切り分ける
2. 定期実行そのものが動いていないなら `定期ジョブ` を見る
3. 生成依頼が拾われていない、または dispatch 前後で止まっていそうなら `生成ファイルイベント` を見る
4. 実際に生成ジョブが失敗した、または retry の履歴を追いたいなら `生成ファイル実行履歴` を見る

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

一覧には POST action の `定義を同期` があります。未登録の定義を dispatcher 定義に基づいて登録するための入口で、押下すると `RecurringJobDispatcherJob.perform_now` を実行し、notice 付きで `定期ジョブ` 一覧へ戻ります。前回状態 / 有効状態 / 検索条件を指定している場合、同期後の戻り先でもその一覧条件は維持されます。

`定義を同期` は一覧を表示するだけでは実行されません。通常の `GET /admin/recurring_job_schedules`、filter 変更、reload、詳細から戻る操作、legacy な `sync_definitions=1` query は read-only として扱い、定義同期を起こす操作ではありません。

未登録 0 件と filter あり 0 件は読み分けます。

- filter なしで 0 件の場合は、登録済み定期ジョブがまだない状態です。まず空状態説明と `定義を同期` を確認し、dispatcher 定義に基づいて登録する入口として扱います。
- 前回状態、有効状態、検索条件がある状態で 0 件の場合は、未登録ではなく条件不一致です。検索 form の `絞り込み解除` または一覧 0 件行の `すべての定期ジョブを見る` で条件を外すか、条件値を見直してから再確認します。
- 表示設定 editor は、行がある場合の列表示補助です。定義の登録、filter 条件、dispatcher 実行、job retry の意味は変えません。

一覧は `rails_table_preferences` 対応済みです。`admin_recurring_job_schedules` の表示設定では、`ジョブキー`、`状態`、`間隔`、`次回実行`、`前回enqueue`、`前回開始`、`前回終了`、`前回状態`、`操作` の列を調整できます。`ジョブキー` と `操作` は pin された列として扱われます。

表示設定を使うときの目安:

- 障害 triage では `ジョブキー`、`前回状態`、`前回終了`、`操作` を残すと、詳細画面へ進む対象を見つけやすい
- 実行間隔や次回予定を見たいときは `間隔` と `次回実行` を残す
- `前回enqueue`、`前回開始`、`前回終了` は、dispatcher が拾ったか、実行が開始したか、完了まで進んだかを分けて読むための列として扱う
- 未登録 0 件では、列表示設定より先に空状態説明と `定義を同期` の読み方を確認する。表示設定は schedule 行が登録された後に使う
- filter あり 0 件では、表示設定で列を増やしても条件不一致は解消しない。前回状態、有効状態、検索語を見直すか、`絞り込み解除` / `すべての定期ジョブを見る` で条件なし一覧へ戻る
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

`実行履歴` は 50 件ずつ表示され、必要に応じて前後のページへ移動できます。初期表示はこれまでと同じ 50 件入口です。古い run を追う場合は、状態、`ActiveJob ID / エラー`、予定時刻 filter で対象を絞り、表示範囲と全件数を見ながら過去ページへ進みます。`ActiveJob ID / エラー` 検索は `active_job_id` と `error_message` の断片を対象にし、検索語は前後の空白を落としてから最大 100 文字まで適用されます。長い error log 全文ではなく、ActiveJob ID の一部や特徴的なエラー断片で探します。履歴の `状態` filter は詳細画面内の run 表示にだけ効き、一覧側の前回状態 filter や検索欄とは役割が異なります。

実行履歴では `予定時刻(開始)` / `予定時刻(終了)` でも絞り込めます。date-only の `YYYY-MM-DD` を入れた場合、開始側はその日の beginning of day、終了側は end of day として扱われます。日時まで指定した場合は、その日時を境界として扱います。

予定時刻 filter を使う場面:

- ある時間帯に dispatcher が拾ったはずの run を切り分けたい
- 状態 filter や `ActiveJob ID / エラー` 検索と組み合わせ、特定の予定時刻範囲に発生した失敗だけを確認したい
- `次回実行` や `前回enqueue` の時刻から、対象 schedule の詳細履歴へ戻って確認したい

実行履歴の page 移動では、`run_status`、`q`、`scheduled_from`、`scheduled_to`、`return_to`、`per_page` が維持されます。表示件数は 50 件または 100 件を選べますが、全件一括表示ではありません。page が範囲外の場合は、存在する最後のページへ丸めて表示されます。

予定時刻に不正な入力がある場合、詳細画面には `予定時刻(開始)` または `予定時刻(終了)` の warning が表示され、その条件だけが適用されません。片方だけ有効な日時条件がある場合は、有効な条件だけで絞り込まれます。warning が出ている状態で 0 件になった場合は、状態・検索語・予定時刻を見直すか、`絞り込み解除` で履歴の先頭ページへ戻ってから再確認します。

`即時実行を要求` は `run_requested_at` を更新し、`RecurringJobDispatcherJob` を enqueue します。用途は「定期設定や関連データを待たずに、この定義を一度早めに走らせたいとき」です。定義そのものの修正や手作業での個別ジョブ再実行ではありません。`定義を同期` が dispatcher 定義を schedule 行へ登録・更新する入口であるのに対し、`即時実行を要求` は既に存在する schedule 1 件の実行要求です。

## 4. 生成ファイルイベント

`生成ファイルイベント` は、生成処理の入口になった event を確認する画面です。controller では status / operation / event_source / path / q / scheduled_at で絞り込みできます。

検索欄 `イベントID / パス / エラー` は first slice として、`GeneratedFileEvent.public_id`、path、`error_message` を部分一致で検索します。検索語は前後の空白を `squish` してから最大 100 文字まで適用され、画面の検索欄にも同じ上限が表示されます。path 検索では Windows 区切り文字 `\\` を `/` として扱います。

専用の `パスを含む` filter と `q` の使い分けは次です。

- `パスを含む`: path だけを対象に、生成対象の場所から event を絞る。入力値は前後空白を落としてから最大 100 文字まで適用され、`\\` は `/` として検索される
- `イベントID / パス / エラー`: 手元に残った event ID、path 断片、error message 断片から横断的に探す。長い error log や path 全文ではなく、100 文字以内の短い特徴語で絞る
- どちらも status / operation / event_source / scheduled date filter と AND 条件で併用される

`実行予定日(開始)` / `実行予定日(終了)` は event の `scheduled_at` を絞るための条件です。日付だけを入れた場合、開始側はその日の 00:00 以降、終了側はその日の 23:59 までを含めます。日時まで指定した場合は、その日時を境界として扱います。不正な日時は warning として表示され、その条件だけが適用されません。

この画面を先に見る場面:

- 生成対象の変更が入ったはずなのに、実行履歴へ進んでいない
- どの event source から失敗が出ているかを見たい
- path や scheduled time を手掛かりに pending / failed を洗いたい
- 手元に残った `gfe...` の event ID、path 断片、error message 断片から対象 event を探したい

一覧は `rails_table_preferences` 対応済みです。`admin_generated_file_events` の表示設定では、`イベントID`、`状態`、`パス`、`操作種別`、`発生元`、`エラー`、`回数`、`実行予定`、`処理完了`、`操作` の列を調整できます。

表示設定を使うときの目安:

- dispatch 前後の詰まりを見るときは `イベントID`、`状態`、`パス`、`発生元`、`実行予定`、`操作` を残す
- 失敗調査では `エラー` と `回数` を残すと、同じ event の再発や一括再投入対象を読みやすい
- 表示設定は列の見え方だけを変え、filter、検索条件、再投入対象、status counts は変えない

一覧上部の `表示フィルタ` quick link は、現在選択中の status を読み返すための補助です。status 未指定時は `すべて`、`status=failed` などを指定した場合は該当 status だけが current として強調され、`aria-current="page"` が付きます。`すべて` quick link は status 条件だけを外し、path / q / operation / event_source / scheduled date などの他条件は維持します。これは表示中の status を確認する cue であり、一括再投入対象の有無や `現在の条件で再投入対象` の件数を変える操作ではありません。

active filter がある状態で 0 件になった場合は、未登録状態ではなく「現在の条件に一致する event がない」状態として読みます。一覧の 0 件表示に出る `すべての生成ファイルイベントを見る` は、条件を外して全体へ戻る button-style action です。一括再投入対象がないことの証明ではなく、検索条件を解除して対象 event を探し直すための復帰導線として扱います。まず status、operation、event_source、path / q、実行予定日の範囲と warning を見直し、必要なら全体表示へ戻ってから対象を探します。filter なしで 0 件の場合は、まだ生成ファイルイベントが蓄積されていない状態で、この filtered empty state action は表示されません。

filter なしで 0 件の場合に表示される `生成ファイル実行履歴を確認する` は、event がまだない状態でも run 側に履歴が残っていないかを見直すための導線です。これは生成処理の成功、エラーなし、通知不要を保証するものではありません。event がない状態で生成ジョブの結果や site build artifact run を探す必要があるときは、`生成ファイル実行履歴` の status、generator、output writer、event source、作成日、`実行ID / パス / エラー / メタデータ` 検索へ切り替えて確認します。

詳細画面では、その event に関連づいた直近の `GeneratedFileRun` を最大 10 件たどれます。探索対象は current implementation では生成ファイル実行履歴の最新 200 件です。関連 run が見えない場合は、対象 event の public ID を `GeneratedFileRun.metadata.generated_file_event_public_ids` に持つ run が最新 200 件の外に出ている可能性があります。

詳細画面の `エラー` と `メタデータ` は diagnostic preview として読みます。長い本文、raw payload、token / secret、private path 相当の値は表示前に伏せられます。metadata が空の場合は `{}` ではなく `このイベントに補助メタデータはありません。` と表示されます。これは補助情報なしの状態であり、再投入可否、保存済み metadata の有無、外部 provider の正常性を保証するものではありません。

一覧の `イベントID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / operation / event_source / path / q / scheduled date の filter、page / per_page を付けた一覧から入った場合でも、detail の `一覧へ戻る` は同じ条件の一覧へ戻ります。detail で `再投入` を実行したあとも同じ detail に戻り、`一覧へ戻る` の戻り先は保持されます。

関連実行リンクは、生成ファイル実行履歴 detail に event detail への `return_to` を渡します。filter 済み event 一覧から event detail に入り、関連 run を開いた場合は、run detail の `一覧へ戻る` で元の event detail へ戻り、そこから event detail の `一覧へ戻る` で最初の filtered event list へ戻る導線として読みます。この導線は関連 run の探索範囲や再実行対象を広げるものではなく、調査中の戻り文脈を失わないための補助です。

再試行導線は 2 種類あります。

- member の `retry_dispatch`: 対象 event 1 件の `status` を `pending` に戻し、`scheduled_at` を現在時刻へ寄せ、`error_message` と `processed_at` をクリアしたうえで `GeneratedFileEventDispatchJob` を enqueue します。画面上の行 action は `このイベントを再投入` と表示され、button の `title` / `aria-label` には対象 event public ID を含む `再投入キューに投入` cue が入ります
- collection の `retry_failed`: 現在の filter を適用した failed event を古い順に最大 100 件まで同じように `pending` へ戻し、対象が 1 件以上あるときだけ `GeneratedFileEventDispatchJob` を enqueue します。画面上の一括操作は `失敗分を一括再投入` と表示されます

一覧上部の `現在の条件で再投入対象: N 件` は、画面に表示中の行数ではなく、current filter に一致する failed event のうち、古い順で今回 pending に戻せる最大 100 件の数として読みます。`status=processed` や `status=pending` など failed 以外の status filter が残っている場合、一括再投入対象は 0 件になります。`scheduled_from` / `scheduled_to` に不正な日時がある場合は warning が出て、その日時条件は適用されず、残っている有効な条件だけで対象件数が計算されます。warning が意図しない場合は日付を直し、path / q は 100 文字上限と `/` 区切りへの正規化後の条件で対象件数を読み直してから実行します。

ここでの再試行は「event をもう一度 dispatch キューへ戻す」操作です。画面上の語彙は `再投入` ですが、controller action 名や job 名には内部識別子として `dispatch` が残ります。すでに生成ジョブ自体が失敗しているケースの再実行は、次の `生成ファイル実行履歴` 側で扱います。

## 5. 生成ファイル実行履歴

`生成ファイル実行履歴` は、実際に enqueue された `GeneratedFileJob` 系の run を確認する画面です。controller では status / job_id / generator / output_writer / event_source / created_at に加えて、実行ID、パス、エラー、補助メタデータの断片で絞り込みできます。

この画面を先に見る場面:

- 生成ジョブが失敗した後の再実行を判断したい
- 同じ run の retry 親子関係を見たい
- event から dispatch された後、どの generator / output writer で失敗したかを追いたい
- 手元に残った `gfr...` の実行ID、入力パス、変更ファイル、生成パス、エラー断片、run metadata のID断片から対象 run を探したい
- Docusaurus site build artifact の workflow run id、commit、manifest path から read-only evidence を探したい

検索欄 `実行ID / パス / エラー / メタデータ` は first slice として、`GeneratedFileRun.public_id`、`source_paths`、`changed_files`、`generated_paths`、`error_message`、`metadata` の文字列表現を部分一致で検索します。検索語は前後の空白を `squish` してから最大 100 文字まで適用され、画面の検索欄にも同じ上限が表示されます。関連イベントを探す場合は、GeneratedFileEvent 側の path や本文を横断検索するのではなく、run metadata に残っている `generated_file_event_public_ids` などのID断片を手掛かりにします。

`Docusaurus site build / docs-site artifact` の read-only evidence は `GeneratedFiles::SiteBuildArtifactRunRecorder` により `GeneratedFileRun` として保存されます。代表値は `job_id=docusaurus_site_build_artifact`、`generator=docusaurus_site_build`、`output_writer=docs_site_artifact`、`event_source=docusaurus_site_build`、`generated_paths` の `docs-site.tar.gz` と `publish/manifest/publish.json` です。metadata には artifact 名、source repo / branch / commit、workflow run id / attempt、manifest path、manifest document count だけを残します。

この site build artifact run は、artifact 本体、manifest 全文、CI log、import API payload、secret-like env、private path を保存する画面ではありません。replay、rebuild、alert、scheduled job、artifact download / preview もこの runbook の current support ではありません。保存境界の詳細は [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) を確認します。

長い metadata JSON や error log 全文をそのまま貼るのではなく、`gfr...` の一部、入力パスや生成パスの特徴語、エラー文の短い断片、metadata に残る event public ID、workflow run id、commit hash、manifest path など、100 文字以内の手掛かりで探します。検索対象を変えたい場合も、status / job_id / generator / output_writer / event_source / created date filter は残したまま、短い断片を差し替えて再検索します。

検索条件は status / job_id / generator / output_writer / event_source / created date filter と併用できます。検索 0 件の場合は、通常の未登録状態ではなく「条件に一致する生成ファイル実行履歴はありません。」と表示されます。画面下部の 0 件表示に出る `すべての生成ファイル実行履歴を見る` は、現在の filter を外して全件表示へ戻る button-style action です。bulk retry の対象がないことを証明するものではないため、status、job_id、generator、output_writer、event_source、q、作成日の条件と warning を見直し、必要なら全体表示に戻ってから対象 run を探します。filter なしで 0 件の場合は、まだ生成ファイル実行履歴が蓄積されていない状態で、この filtered empty state action は表示されません。

`作成日(開始)` / `作成日(終了)` は run の `created_at` を絞る条件です。日付だけを入れた場合、開始側はその日の 00:00 以降、終了側はその日の 23:59 までを含めます。これは生成ファイルイベント側の `実行予定日` filter ではなく、生成ファイル実行履歴側の `作成日` filter の cue として読みます。日時まで指定した場合は、その日時を境界として扱います。

詳細画面では次を確認できます。

- 関連する `generated_file_event_public_ids`
- `retry_of_generated_file_run_public_id`
- その run を親とする retry child runs

派生した再実行は `retry_of_generated_file_run_public_id` metadata を DB query で直接探すため、現在は最新 200 件の実行履歴に入っていない古い retry child も表示対象になります。表示は自身を除いた最大 10 件、新しい順です。表示中の run が retry child の場合は、同じ parent に紐づく sibling retry child も同じ欄でたどれます。

この探索範囲は `GeneratedFileRun` detail の retry 親子表示に限ります。`GeneratedFileEvent` detail の related runs は引き続き最新 200 件の実行履歴から `generated_file_event_public_ids` を見る境界なので、event から見えない古い run は `生成ファイル実行履歴` の検索欄で event public ID や retry parent ID を指定して探します。

一覧の `実行ID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。status / job_id / generator / output_writer / event_source / created date / 実行ID・パス・エラー・メタデータ断片による絞り込みや page / per_page を保ったまま detail へ入り、`一覧へ戻る` で同じ一覧条件へ戻れます。detail で `再実行` を実行したあとも同じ detail に戻るため、再実行前に見ていた一覧条件を失わずに続きの確認ができます。

関連イベント、再実行元、派生した再実行のリンクも、detail に渡された安全化済み `return_to` を引き継ぎます。絞り込み済みの `生成ファイル実行履歴` 一覧から detail に入り、関連イベントや親子 run をたどったあとでも、各 detail の `一覧へ戻る` は元の status / generator / page / per_page / q などを含む一覧文脈へ戻るための導線として読みます。unsafe な `return_to` は既存の fallback 境界で通常の一覧 URL に戻され、関連リンク経由で外部 URL や protocol-relative URL を広げる用途には使いません。

再試行導線は 2 種類あります。

- member の `retry_run`: 対象 run の `changed_files` と `job_id` を使って `GeneratedFileJob` を再 enqueue します。一覧の行単位 button label は `この行を再実行` で、表示中の 1 run だけを対象にします
- collection の `retry_failed`: 現在の filter を適用した failed run を古い順に最大 100 件まで再 enqueue します。一覧上部には `現在の条件で再実行対象` として、実際に今回 enqueue 対象になる failed run 件数が表示されます。対象が 1 件以上ある場合は「現在条件に一致する古い失敗分から最大100件」の cue が出ます。button 実行時には、対象件数と「古い順に最大100件」を含む確認ダイアログが出ます。対象が 0 件の場合は bulk retry button が disabled になり、対象なしの cue が表示されます

実行履歴 detail の header action にある `この実行を再実行` は、現在開いている 1 run だけを再実行キューへ投入する member action です。近くの補足 copy は、元の実行履歴が診断用に残ること、再実行後の結果は新しい実行 ID で確認することを読むための cue です。これは bulk retry、対象 preview、承認 workflow、自動 retry policy、job dispatch 条件の変更ではありません。対象や条件を広げたい場合は detail action ではなく、一覧側の filter と `現在の条件で再実行対象` を確認してから collection retry を使います。

retry metadata には `retry_of_generated_file_run_public_id`、`retry_requested_at`、`retry_requested_by_user_id`、bulk 時の `bulk_retry` が入るため、詳細画面では親 run と子 run の関係を追えます。

自動リトライの first slice は、`ai_usecase_decision_flow` の `filesystem` writer が failed になった run だけを対象にします。`document_version` writer、import、mail、webhook、手動 retry / bulk retry で作られた child run は自動 retry の対象外です。自動 retry は parent run 1 件につき 1 回までで、metadata には `retry_of_generated_file_run_public_id`、`retry_requested_at`、`retry_requested_by_user_id: nil`、`auto_retry: true`、`retry_reason` が入ります。enqueue には既存の `GeneratedFileJob` と同じ `job_id` / `changed_files` を使うため、既存 concurrency key の範囲内で扱います。

## 6. event 再投入と run 再実行の違い

迷ったときは、どこで失敗しているかで選びます。

- event 再投入を使う: 変更イベントはあるが dispatch し直したい、または `GeneratedFileEvent` 側の pending / failed を戻したいとき
- run 再実行を使う: すでに `GeneratedFileRun` が作られており、実際の生成ジョブをもう一度流したいとき

言い換えると、event は「生成依頼の入口」、run は「実際の生成処理」です。両方の画面を行き来できるよう、event 詳細から related runs、run 詳細から related event public IDs を確認します。

## 7. bulk retry を使うときの見方

event / run の `retry_failed` はどちらも current filter を前提に、古い順で最大 100 件まで処理します。まとめて流す前に、少なくとも次を確認します。

- status 以外の filter が残っていないか。event 側では failed 以外の status filter が残っていると一括再投入対象は 0 件になる
- event source / generator / output writer の切り分けが意図どおりか
- path や created/scheduled time の範囲が広すぎないか
- event 側で `イベントID / パス / エラー` 検索を使っている場合、意図した failed event だけに絞れているか
- run 側で実行ID・パス・エラー・メタデータ検索を使っている場合、意図した failed run だけに絞れているか

イベント側の一覧では、bulk retry action の近くに `現在の条件で再投入対象: N 件` が表示されます。この件数は、current filter に一致する failed event のうち、古い順で今回 pending に戻る最大 100 件の数です。`N` が 0 件の場合は一括再投入できません。invalid scheduled date warning が出ている場合は、その日時条件が外れた状態で対象件数が出ているため、日時条件を直すか、残っている条件だけで意図どおりか確認してから実行します。

run 側の一覧では、bulk retry action の近くに `現在の条件で再実行対象: N 件` が表示されます。この件数は、画面に表示中の行数や一覧全体の `@total_count` ではなく、current filter に一致する failed run のうち、古い順で今回 enqueue 対象になる最大 100 件の数として読みます。`N` が 0 件の場合は一括再実行できません。`N` が 100 件の場合でも、条件一致 failed run が 100 件を超えている可能性があるため、必要なら created date や generator / output writer / event source を狭めてから再実行します。

一括再実行 button を押すと、現在条件に一致する failed run の対象件数と、古い順に最大 100 件を再 enqueue することを確認するダイアログが出ます。これは対象 preview や承認 workflow ではなく、現在の filter と件数を最後に読み直すための誤操作防止 cue です。条件や件数が意図と違う場合はキャンセルし、filter を絞り直してから再実行します。

日時 filter に不正な入力がある場合、一覧には「日時フィルタを確認してください。」という warning が表示され、その日時条件が適用されなかったことが分かります。warning が出ている状態でも bulk retry cue は表示されます。bulk retry 前に日付入力を直すか、意図して外した条件だけが残っているかを確認し、`現在の条件で再実行対象` の件数を見てから実行します。

この runbook では current implementation の説明に留め、運用上の承認ルールや retry 回数ポリシーまでは新設しません。

## 8. 自動リトライを検討する前に

手動の event 再投入 / run 再実行を超えて自動リトライを入れる場合は、[自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md) で対象処理ごとの冪等性、二重実行リスク、必要な guard を確認します。

この runbook の retry 導線は現時点では手動運用の説明です。自動化する場合も、import / build / mail / webhook をまとめた基盤 issue ではなく、対象処理 1 つ単位の issue に分けます。

## 9. 関連文書

- [監視・アラート設計](./監視・アラート設計.md)
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md)
- [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
