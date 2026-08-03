# AI向けコンテキストexport運用runbook

この runbook は、案件詳細の `AI向けコンテキスト` 画面で、案件内文書を AI に渡すための context として確認・export するときの current behavior をまとめます。

## 1. 入口

1. 案件詳細を開く
2. actions の `AI向けコンテキスト` を開く
3. まず HTML preview で出力モード、出力対象件数、`含まれる文書`、`除外された文書` を確認する
4. 必要に応じて `概要中心` / `本文込み` を切り替える。URL param、JSON、Markdown、AccessLog では内部 mode key として `compact` / `full` が残る
5. 必要に応じて `対象文書を絞り込む` で export scope を選び、HTML preview を更新する
6. `JSON` または `Markdown` で export する

route は `project_ai_context_path(project)` です。URL 上は `projects/:project_code/ai_context` 配下で、案件 access がない user は `require_project_access!` で止まります。

## 2. HTML preview で見ること

HTML preview は、download する前に export plan を読む画面です。

- `出力モード`: HTML preview の主表示は `概要中心` / `本文込み`。補助表示として `出力モードID / mode: compact` または `出力モードID / mode: full` を併記する
- `出力対象`: JSON / Markdown に含まれる文書数
- `含まれる文書`: viewer が閲覧でき、export 対象になる文書
- `除外された文書`: scope 内にはあるが viewer が閲覧できない文書
- `reason`: current code では `viewable` または `not_viewable`

preview を見た時点でも AccessLog は残ります。download 前の確認画面として扱い、`除外された文書` がある場合は、権限設定を先に見直すべきか、export 対象外として問題ないかを判断してから進めます。

案件内文書が多い場合でも、HTML preview の checkbox 候補と `含まれる文書` / `除外された文書` table は先頭 50 件を基本に表示します。これは画面描画を bounded にするための preview 境界であり、未選択状態の JSON / Markdown export は引き続き閲覧可能な案件内文書全体を対象にします。明示選択済みの文書が先頭 50 件の外にある場合は、選択状態を確認できるよう checkbox 候補に追加表示します。

`出力` card では、JSON / Markdown action の直前に現在の文書 scope を短く読み返せます。

- 未選択の all scope では `現在の対象: 全件 / 出力対象: N件` と表示される
- 明示選択済みの selected scope では `現在の対象: 選択中 / 選択ID: N件 / 出力対象: M件` と表示される
- `document_q` で候補検索中でも、検索だけでは JSON / Markdown の対象範囲は変わらない。出力 card の `検索は候補の絞り込みです。JSON / Markdown は現在の対象範囲を出力します。` を押下前の最終確認として読む
- selected scope のときは、同じ `出力` card に `選択範囲の引き継ぎ` が表示される。`出力モード`、`出力モードID / mode`、`範囲: 選択中`、`選択ID`、`案件内候補`、`出力対象`、`候補外` の件数を、JSON / Markdown を押す前の read-only summary として読む
- `選択範囲の引き継ぎ` の文書 table は、viewer が閲覧できる選択文書だけを `タイトル`、`slug`、`公開ID` で表示する。案件外 ID、存在しない ID、閲覧不可文書の raw ID や public_id は表示しない
- 選択文書 summary が表示上限を超える場合は、画面に出ている件数と全件数の補足文が出る。JSON / Markdown 出力には閲覧可能な選択文書全件が含まれるため、table の表示件数だけを export 件数として読まない
- 閲覧可能な選択文書が 0 件の場合は、その旨の muted copy を確認する。候補外 ID や閲覧不可文書の raw ID を調査材料として画面に出す仕様ではない

## 3. 概要中心 / 本文込み（mode: compact / full）の使い分け

`概要中心` は既定の出力モードです。内部 mode key は `compact` で、URL param、JSON、Markdown、AccessLog では `mode=compact` として残ります。各文書について metadata と `search_body_text` の先頭要約だけを出します。

- AI に渡す文書一覧や候補整理をしたい
- まず対象文書の数やカテゴリを確認したい
- 本文を広く渡しすぎたくない

`本文込み` は内部 mode key が `full` の出力モードです。URL param、JSON、Markdown、AccessLog では `mode=full` として残り、各文書の `search_body_text` 本文を含めます。

- AI に文書本文を読ませたい
- 差分調査や要約作成の材料として本文が必要
- export 前に `含まれる文書` が意図どおりであることを確認済み

HTML preview では利用者向けラベル（`概要中心` / `本文込み`）を先に読み、raw key（`compact` / `full`）は URL や export payload、監査ログと突き合わせるための識別子として扱います。

current exporter が扱う本文は `DocumentVersion#search_body_text` です。添付ファイルは binary や元ファイル本文ではなく、`latest_version.document_files` の metadata manifest だけを export します。Docusaurus build artifact、コメント、監査ログは export 本文には含めません。

## 4. JSON / Markdown の使い分け

`JSON` は機械処理しやすい構造化 export です。`project`、`viewer`、内部 mode key の `mode`、`summary`、`documents` を含みます。`mode=compact` では文書ごとに `summary`、`mode=full` では `body_text` が入ります。

文書ごとの `document_files` には、`public_id`、`file_name`、`content_type`、`file_size`、`scan_status`、`downloadable` を含めます。`downloadable` は `DocumentFile#downloadable_by?(viewer)` の結果です。signed URL、storage path、binary content、添付本文の抽出結果は含めません。

`Markdown` は人が読みやすく、そのまま AI prompt に貼りやすい export です。案件名、code、内部 mode key、viewer、document_count の後に、文書ごとの metadata、添付がある場合の `Attachments` block、summary または本文が並びます。

どちらの形式でも、export される `documents` は viewer が閲覧できる文書だけです。HTML preview で `除外された文書` に出た文書は、JSON / Markdown の文書本文にも添付 metadata manifest にも入りません。

## 5. 権限と監査ログ

AI context export は、案件 access と文書 visibility の両方を前提にします。

- 案件 access は `Project.accessible_to(current_user)` と `require_project_access!` の範囲で扱う
- 文書ごとの export 可否は `visible_in_portal_for?(viewer)` で判定する
- JSON / Markdown には viewer が閲覧できる文書だけを入れる
- HTML preview は `含まれる文書` と `除外された文書` を分けて表示する
- 添付 metadata manifest は閲覧可能文書の `latest_version.document_files` だけを対象にする
- 添付ごとの download 可否は boolean として出し、取得可能 URL は出さない

AccessLog は HTML preview と JSON / Markdown download の両方で作成されます。

- HTML preview: `action_type: view`
- JSON / Markdown: `action_type: download`
- `target_type: ai_context`
- `target_name: mode=<mode>;scope=all|selected;selected_count=<n>;scoped_count=<n>;exported_count=<n>`

`target_name` の `mode` は、HTML preview 上の `概要中心` が `compact`、`本文込み` が `full` として保存されます。`scope` は `document_ids[]` がない場合に `all`、明示選択がある場合に `selected` です。`selected_count` は request で指定された文書 ID 数、`scoped_count` はそのうち現在の案件内文書として解決できた数、`exported_count` は viewer が実際に export できる文書数です。案件外または存在しない ID は候補外として数だけ扱い、文書 ID や title は AccessLog に残しません。必要な場合は preview の `明示選択` / `案件内候補` / `出力対象` summary と、`含まれる文書` / `除外された文書` / `選択範囲の引き継ぎ` を照合します。

監査ログ画面では、`target_type=ai_context` を指定したうえで `AI出力モード` と `AI出力範囲` を併用できます。`AI出力モード` の画面表示と有効条件 summary は `コンパクト` / `詳細` で、内部値として `compact` / `full` が残ります。`AI出力範囲` は `全件` / `選択` で、`target_name` に保存された `mode=<value>;` / `scope=<value>;` を見る補助 filter です。`target_type` が `ai_context` でない場合、AI context 固有 filter は条件から外れます。

一覧の `対象` 列では、AI context の `mode`、`scope`、`選択数`、`出力数` が badge として表示されます。`scoped_count` を含む保存値そのものを照合したい場合は、同じ cell の `監査用 raw target_name` を開きます。壊れた形式や未知の形式の `target_name` は badge 化せず、raw 表示へ戻る前提で読みます。

preview と download を突き合わせるときは、`操作=view` が HTML preview、`操作=download` が JSON / Markdown export です。同じ案件・利用者・mode・scope で preview だけが残っている場合は、download まで進まなかった可能性があります。`selected` scope で `selected_count` と `scoped_count` がずれる場合は、案件外または存在しない ID が候補外として無視されています。`scoped_count` と `exported_count` がずれる場合は、案件内候補のうち viewer が閲覧できないものが `除外された文書` に出ていないかを HTML preview 側で確認します。

ログ作成に失敗した場合は controller が error log を出して処理を継続します。監査上は `監査ログ` 画面で `target_type` や action、AI context mode / scope を見て、preview と download の両方が残る前提で確認します。

## 6. scope selection UI の current support

HTML preview には `対象文書を絞り込む` card があり、viewer が閲覧できる案件内文書から export scope を選べます。

- 未選択の状態では、閲覧可能な案件内文書全体を対象に preview / export する
- `document_ids[]` checkbox で文書を選び、`選択した文書でpreview` を押すと HTML preview が選択 scope で更新される
- `概要中心` / `本文込み` の切り替え link と `JSON` / `Markdown` export link は、選択済みの `document_ids[]` を引き継ぐ
- `選択済みだけ表示` を押すと、現在選択している閲覧可能文書だけを checkbox 候補として確認できる。候補表示の切り替えであり、JSON / Markdown の対象は `document_ids[]` の選択 scope のまま変わらない
- `検索候補へ戻る` は `選択済みだけ表示` から通常の候補表示へ戻る link。`candidate_view=selected` だけを外し、現在の mode、`document_ids[]`、検索中であれば `document_q` を維持する
- `すべての文書に戻す` を押すと `document_ids[]` と `document_q` を外し、現在の mode のまま全体 scope に戻る
- 選択 scope に含めた文書でも、viewer が閲覧できなければ JSON / Markdown には入らず、HTML preview の `除外された文書` で確認する
- selected scope では、`出力` card の `選択範囲の引き継ぎ` で出力モード / 出力モードID / mode / 範囲 / 選択ID / 案件内候補 / 出力対象 / 候補外の件数と、閲覧可能な選択文書の title / slug / 公開IDを確認できる
- `選択範囲の引き継ぎ` は export 前の read-only summary であり、保存済み preset、権限変更、外部 AI 送信、文書本文の再表示ではない

controller は `document_ids` param を受け取り、指定された案件内文書だけを scope として扱います。UI から選んだ場合も、手動で query を渡した場合も、最終的な export 可否は viewer の文書 visibility で判定します。

checkbox 候補は画面表示用に上限付きです。案件内の閲覧可能文書が 50 件を超える場合、HTML preview は表示中件数と閲覧可能件数を分けて示し、先頭 50 件を候補として描画します。明示選択済みの文書がその外にある場合は、選択状態を保つため追加表示します。候補表示の上限は preview の描画境界であり、未選択時の all export semantics や JSON / Markdown の対象件数を減らすものではありません。

`文書名 / slug で検索` は checkbox 候補の表示を絞る補助です。`document_q` は title / slug の断片一致だけを見ます。検索条件がある場合、画面は検索結果件数、閲覧可能件数、表示中件数を分けて示します。

検索は export 対象をその場で確定する操作ではありません。検索しただけでは、JSON / Markdown export link は現在の対象範囲を維持します。検索結果から対象を変える場合は、checkbox を確認して `選択した文書でpreview` を押し、HTML preview の `出力対象` 件数と `含まれる文書` / `除外された文書` / `選択範囲の引き継ぎ` を見てから JSON / Markdown を出力します。

検索条件を変えても明示選択済みの文書は checkbox 候補に残ります。これは選択状態の見落としを避けるための current UI であり、検索結果だけを export 対象にする意味ではありません。全体 scope に戻す場合は `すべての文書に戻す` を使います。

選択済みだけ表示中に、権限変更や公開状態変更で確認できる閲覧可能な選択文書が 0 件になった場合は、empty state に `検索候補へ戻る` と `すべての文書に戻す` が出ます。`検索候補へ戻る` は選択 scope を保ったまま通常候補へ戻って確認する導線、`すべての文書に戻す` は選択 scope 自体を解除する導線として読み分けます。候補 0 件は「export 全体が空」とは限らないため、`出力対象` 件数、`含まれる文書`、`除外された文書`、`選択範囲の引き継ぎ` を合わせて確認します。

この runbook では、保存済み export 設定、外部 AI サービス連携、添付 binary の export は current support として扱いません。

## 7. この画面でやること / やらないこと

### やること

- 案件単位の AI context preview
- `概要中心` / `本文込み` の切り替え（内部 mode key は `compact` / `full`）
- 対象文書の選択 scope による preview / export
- selected scope の read-only handoff summary 確認
- checkbox 候補の文書名 / slug 検索
- JSON / Markdown export
- export 対象と除外文書の確認
- 添付ファイルの最小 metadata manifest の export
- access log を残す前提での preview / download
- 監査ログで AI context の mode / scope / selected_count / scoped_count / exported_count を確認する

### やらないこと

- 文書権限の変更
- 保存済み export 設定の管理
- 外部 AI サービスへの自動送信
- 添付 binary、signed download URL、storage path、添付本文抽出の export
- コメントや監査ログ本文の export
- AI prompt の保存や履歴管理

## 8. current support の境界

- この runbook は current `main` の `ProjectAiContextsController`、`AiContextHashExporter`、`AiContextMarkdownExporter`、`AiContextExportPlan`、`Admin::AccessLogsController` を正本にします
- HTML preview の主表示は `概要中心` / `本文込み`、URL param・JSON・Markdown・AccessLog の内部 mode key は `compact` / `full` として扱います
- JSON / Markdown は viewer が閲覧できる文書だけを export する説明に閉じます
- 添付 metadata manifest は閲覧可能文書の `latest_version.document_files` から作り、download 可否は `downloadable` boolean で表します
- HTML preview の `対象文書を絞り込む` は、export scope を選ぶ current 表示として扱います
- HTML preview の `出力` card では、JSON / Markdown action 近くの `現在の対象` cueで all / selected scope と出力対象件数を押下前に読み返せます
- HTML preview の `選択範囲の引き継ぎ` は、selected scope の出力モード / 出力モードID / mode / 範囲 / count と閲覧可能な選択文書だけを title / slug / 公開IDで確認する read-only summary として扱います
- HTML preview の `文書名 / slug で検索` は checkbox 候補を探す補助であり、export 対象は `選択した文書でpreview` 後に切り替わるものとして扱います
- HTML preview の `選択済みだけ表示` / `検索候補へ戻る` は checkbox 候補の見え方を切り替える導線であり、選択 scope 自体は `document_ids[]` が維持される限り変わりません
- HTML preview の checkbox 候補と plan table、selected handoff table は表示上限付きで、all export semantics や selected export semantics の対象件数とは分けて扱います
- HTML preview の `除外された文書` は、download 対象外を確認するための current 表示として扱います
- 案件外 ID、存在しない ID、閲覧不可文書の raw ID や public_id は、selected handoff table に表示しません
- 監査ログの `AI出力モード` / `AI出力範囲` filter は `target_type=ai_context` の `target_name` を使う補助 filter です。画面表示は `コンパクト` / `詳細` と `全件` / `選択`、内部値は `compact` / `full` と `all` / `selected` として読み分け、AccessLog schema 正規化や任意の `target_name` 全文検索ではありません
- 監査ログの AI context badge は `target_name` の既知形式を読みやすくする表示補助であり、保存値そのものは `監査用 raw target_name` で確認します
- `selected_count` / `scoped_count` / `exported_count` は、request ID 数、案件内候補数、閲覧可能な出力数を分けて読む監査補助です。案件外 ID や存在しない ID は raw ID として表示しません
- 外部 AI 連携、保存済み export 設定、添付 binary export は未実装として扱い、実装済みとは書きません
- export 対象の追加拡張が必要な場合は、別 issue で code / spec と一緒に判断します
