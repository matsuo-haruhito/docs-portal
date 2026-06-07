# 監査ログ運用runbook

この runbook は、管理画面の `監査ログ` を日常運用で見返すときの入口をまとめる。

新しい監査ポリシーはここでは定義しない。current 実装と既存仕様 docs を前提に、どの絞り込みで何を確認し、必要に応じてどこへ戻るかを整理する。

## 先に見るもの

1. AccessLog が何を記録対象にするかを確認したいときは [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)
2. request spec で守っている current contract を見たいときは [テスト方針](./テスト方針.md)
3. 管理画面の位置関係は `app/views/admin/_nav.html.slim` の `監査ログ` を起点に確認する

## 画面の役割

`admin/access_logs` は internal admin だけが使える監査画面で、文書閲覧や添付ダウンロードの代表的なアクセス証跡を新しい順に確認する。

current 実装の前提:

- 一覧は `accessed_at desc, id desc` の順で、1 ページあたり 200 件まで表示する
- 200 件を超える場合は `次の200件` / `前の200件` で page 移動でき、page link は既存 filter 条件を維持する
- `page` は current controller の上限内だけを採用し、`limit` param では表示件数や取得上限を広げない
- `現在の条件でCSV export（最新200件）` は、現在の filter 条件に一致する証跡を新しい順に最新 200 件まで固定列で出力する。page 移動中でも export は現在 page ではなく条件一致の最新 200 件を対象にする
- 絞り込みは `action_type` `target_type` `project_id` `company_id` `user_id` `q` `document_q` `from` `to` `ai_context_mode` `ai_context_scope` を受け付ける
- 画面上の `AI出力モード` / `AI出力範囲` filter は、それぞれ `ai_context_mode` / `ai_context_scope` を使う
- AI context の `mode` / `scope` filter は `target_type=ai_context` のときだけ有効になり、他の `target_type` では無視される
- `q` は一覧に表示される `target_name` と `ip_address` に対して部分一致で絞り込む
- `document_q` は文書タイトルと `slug` の両方に対して部分一致で絞り込む
- `q` と `document_q` は OR ではなく AND で併用されるため、target / IP と文書条件の両方に合うログだけが残る
- `from` / `to` は `accessed_at` の日付範囲で絞り込み、指定後も一覧の並び順と 1 ページ 200 件表示は変わらない
- 不正な日付入力は 500 にせず、その日付条件だけを無視する。画面には除外された条件が `開始日` / `終了日` として warning 表示される
- 一覧には `監査ログ一覧の表示設定` editor があり、`日時` `操作` `対象` `ユーザー` `会社` `案件` `文書` `版` `IPアドレス` の表示列を切り替えられる
- 一覧から `文書` は project/document detail、`版` は document version detail へ戻れる

## 絞り込み項目の見方

### 1. 操作

- `action_type` は `view` `download` などの代表操作を絞り込む
- まず「閲覧だけを見たい」「ダウンロードだけを見たい」を分けたいときに使う

### 2. 対象種別

- `target_type` は current UI では `page` `file` `zip` `ai_context` を扱う
- HTML 本文の閲覧、添付ファイル配布、ZIP 配布、AI context export の利用証跡を切り分けたいときに使う
- AI context export は HTML preview と JSON / Markdown download の証跡を `target_type: ai_context` として残す
- 一覧の `対象` 列には対象種別に加えて `target_name` が出るので、同じ種別の中でもどのファイルやページ、または AI context export の mode だったかを見分けやすい

### 3. AI出力モード / AI出力範囲

- `AI出力モード` は `compact` / `full` のどちらかで AI context export の証跡を絞り込む。内部 param は `ai_context_mode`
- `AI出力範囲` は `全件` / `選択` のどちらかで AI context export の証跡を絞り込む。内部値は `all` / `selected`、内部 param は `ai_context_scope`
- どちらも `対象種別` が `ai_context` のときだけ有効になる。`page` `file` `zip` では `AI出力モード` / `AI出力範囲` を選んでも条件から外れる
- 不正な mode / scope 値は無視されるため、意図した条件になっているかは `有効な条件` の badge で確認する
- 一覧の `対象` 列では、AI context export の `mode`、`scope`、選択件数、出力件数が badge として表示される
- 保存された値の監査用 preview を照合したいときは、`対象` 列の `監査用 target_name preview` を開く。token / authorization / private-looking path 風の値は preview 表示に寄るため、raw 値の全文確認場所として扱わない

### 4. 案件 / 会社 / ユーザー

- `project_id` は案件単位の追跡に使う
- `company_id` は社外会社ごとの利用状況を見たいときに使う
- `user_id` は個別利用者の行動確認に使う
- 3 つを組み合わせると、対象をかなり狭くして 200 件単位のページ内で追いやすくなる

### 5. 対象名・IPアドレス

- `q` は一覧に表示される `target_name` と `ip_address` に効く
- ZIP 名、添付ファイル名、page path、AI context export の記録、IP アドレス断片を first touch で探したいときに使う
- 画面 placeholder は `ZIP名・ファイル名・AI context export の記録・IP` で、保存値の内部表現そのものを操作名として読ませるものではない
- `document_q` とは別の検索欄なので、文書 title / slug を探したい場合は `文書名・URL識別子` を使う
- `q` と `document_q` を同時に入れると、対象名または IP に一致し、かつ文書 title / slug にも一致するログだけを表示する
- `%` や `_` を含む入力は LIKE wildcard として広げず、文字列として扱う

### 6. 文書名・URL識別子

- `document_q` は文書タイトルと `slug` の両方に効く
- 管理画面や公開 URL で覚えている文字列が title か slug か分からないときでも、同じ入力欄で探せる
- target file name、ZIP 名、AI context export の記録、IP アドレスを探す欄ではない。これらは `対象名・IPアドレス` の `q` を使う

### 7. 開始日 / 終了日

- `from` は指定日の 00:00:00 以降、`to` は指定日の 23:59:59 までの `accessed_at` に効く
- 「先週の送付後」「特定日の問い合わせ前後」のように、時期を主語に確認したいときに使う
- 案件・会社・ユーザー・対象名・文書名・AI出力モード / AI出力範囲などの既存 filter と併用できる
- 期間指定後も、表示は `accessed_at desc, id desc` の新しい順で 1 ページ 200 件までに留まる。200 件を超える場合は、次ページへ進むか、期間を短くするか、他の条件を足して絞り込む
- 日付として解釈できない入力は、その日付条件だけが除外され、画面に warning が表示される。片方だけ有効な場合は、有効な `開始日` または `終了日` だけで絞り込まれるため、warning の条件名と `有効な条件` の badge を見比べる
- warning が出ている状態で 0 件になった場合は、無効な日付を直すか、日付以外の条件も含めて見直す。意図せず片側だけの期間になっていないかを確認してから CSV export や page 移動を行う

## ページ移動の読み方

一覧は 200 件固定の page として読む。条件に一致する証跡が 200 件を超える場合、画面上部に `次の200件` が出る。

- `次の200件`: 現在の filter 条件を保ったまま、より古い 200 件へ進む
- `前の200件`: 現在の filter 条件を保ったまま、新しい側の 200 件へ戻る
- `page` は内部的なページ番号であり、`limit` を渡して表示件数を増やす操作ではない
- 目的の証跡が古い場合でも、まず案件・会社・ユーザー・対象名・文書名・期間で絞り、必要に応じて page 移動する

AI出力モード / AI出力範囲、日付、案件、会社、ユーザー、対象名、文書名の filter は page link に引き継がれる。page 移動後に条件が外れていないかは、`有効な条件` の badge と表示件数で確認する。

## CSV export の読み方

`現在の条件でCSV export（最新200件）` は、画面に入っている filter 条件を保ったまま、条件一致の最新 200 件を監査用途の固定列で出力する。HTML 一覧の page 移動とは独立しており、2 ページ目を見ている途中でも CSV は current filter の最新 200 件から作られる。

無効な `開始日` / `終了日` が warning で除外されている場合、CSV export にもその無効な日付条件は入らない。片方だけ有効な日付条件が残っている場合は、その有効な片側条件と他の filter 条件に一致する最新 200 件が CSV 対象になる。

CSV の固定列は次の役割で読む。

- `日時` `操作` `対象種別` `対象名` は、一覧と同じ監査証跡の主語を読む列
- `AI context mode` `AI context scope` `AI context selected_count` `AI context exported_count` は、`target_type=ai_context` かつ `target_name` が `mode=...;scope=...;selected_count=...;exported_count=...` として解釈できる場合だけ埋まる
- `ユーザー名` `ユーザーEmail` `会社` `案件コード` `案件名` は、誰がどの案件文脈で操作したかを読む列
- `文書名` `文書URL識別子` `版` は、文書 detail / version detail へ戻るための確認列
- `IPアドレス` は、問い合わせや運用メモと突き合わせる補助列

表示設定との違い:

- `監査ログ一覧の表示設定` は HTML 一覧で見たい列を切り替えるだけ
- CSV columns は監査用途の固定列で、表示設定で非表示にした列も CSV では固定列として出る
- CSV export は無制限全件取得ではなく、任意 `limit` や scheduled report、retention policy 変更も current support ではない

AI context の読み方:

- parse できる AI context target は、`対象名` に保存値を残したまま、mode / scope / selected_count / exported_count を専用列でも読める
- parse できない `target_name` や `target_type=ai_context` 以外の行では、AI context 専用列は空のままになる
- HTML preview / JSON / Markdown download のどの証跡かを調べるときは、まず `対象種別` と AI context 専用列を見て、必要なら `対象名` の保存値と `q` filter の条件に戻る

## 監査ログ一覧の表示設定

`監査ログ一覧の表示設定` は、絞り込み後の一覧で見たい列だけを残して証跡を読みやすくするための editor である。

この設定で変わるのは一覧テーブルの表示列だけで、次は変わらない。

- 絞り込み条件
- 1 ページ 200 件までという表示上限
- page 移動時の filter 維持
- CSV export の固定列と最新 200 件上限
- ログの並び順
- `文書` / `版` から戻れる current detail 導線

使い分けの目安:

- 案件単位で利用者の動きを見たいときは、`日時` `操作` `ユーザー` `会社` `案件` を残す
- どの文書や版にアクセスが集中しているかを見たいときは、`対象` `文書` `版` を残す
- 問い合わせや運用メモと突き合わせたいときは、`IPアドレス` を残して他の列を絞る

一覧が横に広くて読みづらいときは、まず `案件` や `ユーザー` で対象を狭め、そのあと表示設定で列を絞ると current UI を追いやすい。

## 日常確認ポイント

- 想定した案件や利用者に対して、閲覧とダウンロードのどちらが起きているか
- ZIP 配布や添付ダウンロードが特定案件だけに偏っていないか
- ZIP 名、添付ファイル名、AI context export の記録、IP アドレス断片から `対象名・IPアドレス` で目的の証跡を探せているか
- AI context export の HTML preview / JSON / Markdown download が想定した案件や利用者で発生しているか
- AI context export を見るとき、`compact` / `full` と `全件` / `選択` のどちらで出力された証跡なのかを `AI出力モード` / `AI出力範囲` と `対象` 列で確認できているか
- 条件に一致する最新 200 件を共有・保管したいとき、CSV export の固定列と画面の表示設定を混同していないか
- 日付起点で問い合わせや送付後の利用を見たいとき、開始日 / 終了日で対象期間を狭めてから案件・会社・ユーザーを足せているか
- 開始日 / 終了日の warning が出ているとき、除外された条件名と有効な条件を確認してから結果件数や CSV export を読む
- 文書・版・利用者のどれを主語にして見たいのかに合わせて、表示設定で不要な列を外せているか
- 文書 detail や版 detail へ戻って、対象文書や公開状態をその場で見直す必要があるか
- 目的の証跡が見つからないとき、1 ページ 200 件の範囲からあふれていないか。必要なら次ページへ進むか、条件を足して絞り込む

## 変更時の注意

- 期間指定と page 移動は一覧の絞り込み・表示補助であり、監査ログ保存期間や retention policy は変えない
- current UI は 200 件単位の page 移動と、現在の filter 条件に一致する最新 200 件の CSV export を持つ。無制限全件取得、任意の `limit` 指定、scheduled report は current support として扱わない
- CSV export の固定列は画面表示設定とは独立している。表示列を減らしても CSV の監査用固定列は変わらない
- 無効な開始日 / 終了日は warning 表示のうえで除外される。docs や運用メモでは、warning がある状態を「指定期間がそのまま適用された」と読まない
- `q` は `target_name` / `ip_address` の補助検索であり、user_agent 検索や全文検索 index ではない
- `document_q` は title / slug の検索であり、target file name や IP アドレス検索ではない
- AI出力モード / AI出力範囲 filter は `target_type=ai_context` の `target_name` に保存された `mode=<value>;` / `scope=<value>;` を使う補助 filter であり、任意の `target_name` 全文検索ではない
- AI context export の保存値を文字列断片で探したいときは `q` を使う。ただし mode / scope の structured filter は従来どおり `target_type=ai_context` のときだけ有効にする
- `監査ログ一覧の表示設定` は一覧の表示列を切り替えるだけで、記録対象や絞り込み結果そのものは変えない
- company master admin や external user は使えない画面なので、社外利用者向け運用手順としては扱わない

## 戻り先

- 版や添付の公開状態を見直したいときは [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)
- 権限や閲覧境界を見直したいときは [基本モデルと権限](./specs/基本モデルと権限.md)
- 文書ごとの利用傾向を案件単位でまとめて見たいときは [文書利用状況運用runbook](./文書利用状況運用runbook.md)

## 迷ったときの切り分け

- まず利用が起きたかどうかを見たい: `操作` と `対象種別` で絞る
- AI context export の出力形態だけを狭めたい: `対象種別` を `ai_context` にしてから `AI出力モード` / `AI出力範囲` を足す
- どの案件や会社の話かを狭めたい: `案件` `会社` `ユーザー` を足す
- 特定日の前後だけを見たい: `開始日` / `終了日` を入れて、必要なら他の条件を足す。warning が出た場合は、除外された日付条件を直してから結果を読む
- ZIP 名、添付ファイル名、AI context export の記録、IP アドレスから探したい: `対象名・IPアドレス` に断片を入れる
- 文書 detail から利用傾向を振り返りたい: `document_q` で title / slug を入れて戻る
- 一覧が広くて読みづらい: 表示設定で必要な列だけを残す
- 条件に一致する最新 200 件を持ち出して確認したい: `現在の条件でCSV export（最新200件）` を使い、固定列と表示設定の違いを確認する
- 200 件より古い証跡を追いたい: まず filter を維持したまま `次の200件` へ進み、広すぎる場合は期間や対象条件を足す。CSV は current page ではなく最新 200 件の export なので、古い page の証跡を出したい場合は条件をさらに狭める
- 件数傾向や未利用文書を見たい: この画面ではなく `文書利用状況` へ移る
