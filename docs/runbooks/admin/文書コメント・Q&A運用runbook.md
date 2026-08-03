# 文書コメント・Q&A運用runbook

この runbook は、文書詳細・版詳細に表示される `文書コメント` workspace で、利用者向け Q&A と社内向け確認事項を扱うときの現在の運用境界をまとめます。

## 使い分け

| 種別 | 主な用途 | 表示範囲 | 投稿できるユーザー | current flow |
| --- | --- | --- | --- | --- |
| Q&A | 外部ユーザーや利用者にも見せたい質問・回答 | `internal_only: false` の public thread。external user も閲覧対象になる | external user / internal user | `質問する` から投稿し、返信も同じ public thread に残す |
| 確認事項 | 社内レビュー、指摘、修正依頼、位置メモ | `internal_only: true` の internal-only comment。external user には表示しない | internal user | `確認事項を残す` から投稿し、admin が `解決` 操作できる |

`Q&A` は問い合わせや補足説明を文書と一緒に残すための public thread です。external user が投稿する場合、controller は `comment_type` を `question`、`internal_only` を `false` に寄せます。

`確認事項` は社内向けのレビューコメントです。`note` / `issue` / `request_change` を使い分けられ、行番号、対象ファイル、見出しや JSON path などの位置メモを合わせて残せます。

## 表示場所と紐づき

- 文書詳細から投稿したコメントは、その文書のコメントとして扱います。
- 版詳細から投稿したコメント、または workspace が対象版を持つ場合は、`document_version_id` を持ち、一覧上でも版ラベルが表示されます。
- Q&A の返信は parent と同じ文書に属し、parent が版に紐づく場合は同じ版に紐づきます。
- parent と異なる document への返信、または parent と違う visibility の返信は model validation で拒否されます。

## Q&A の読み方

Q&A thread には `受付中` / `回答済み` / `クローズ` の状態ラベルが表示されます。

| ラベル | current status | 読み方 |
| --- | --- | --- |
| 受付中 | `open` | まだ対応中または回答待ちとして扱う質問 |
| 回答済み | `resolved` | 回答・対応が済んだ質問または返信 |
| クローズ | `rejected` | 対応しない、または受付を閉じた質問 |

状態ラベルは Q&A の運用上の読み方です。未解決タブで `クローズ` をどう扱うかは `#1257` の quality contract として分け、ここでは回答済み・クローズ操作の current UI と矛盾しない説明に閉じます。

現時点では、通知、メール、SLA、回答期限、自動エスカレーションはこの runbook の対象外です。状態ラベルは画面上の current label として読み、未実装の workflow を前提にしないでください。

## dashboard の `受付中Q&A候補`

internal user の dashboard には、公開 Q&A のうち受付中の root thread を短く見直すための `受付中Q&A候補` section が表示されます。これは通知、SLA、回答期限、担当割当ではなく、既存の文書または版の Q&A workspace へ戻る read-only handoff です。

表示対象は次の条件に閉じます。

- current user が閲覧できる文書に紐づく Q&A
- `comment_type: question`
- `internal_only: false`
- `status: open`
- `parent_id: nil` の root thread
- `updated_at` の新しい順、同時刻では id の新しい順で最大 5 件

表示される主な情報は、文書名、案件名と code、版ラベル、投稿者、返信有無、最終活動時刻、本文 preview です。版に紐づく thread は版詳細の Q&A tab へ、版を持たない thread は文書詳細の Q&A tab へ戻ります。返信が付いていても root thread が `open` のままなら候補に残り、返信有無で「返信あり」と読めます。

以下は候補に含めません。

- `resolved` / `rejected` の Q&A
- internal-only の確認事項や internal-only Q&A
- 返信単体
- current user が閲覧できない文書の metadata
- archived 文書に紐づく Q&A

external user の dashboard には `受付中Q&A候補` section 自体を表示しません。external user は自分に見える public Q&A を各文書の workspace で確認します。候補 0 件は、dashboard の短い枠に出る open public Q&A root がないという意味であり、問い合わせが存在しない保証、通知 green、SLA 達成、回答済み保証ではありません。必要に応じて文書詳細・版詳細の Q&A tab、検索、投稿者 filter を使って確認してください。

## workspace の `未解決handoff`

internal user の文書コメント workspace には、表示中の文書または版にある未解決 Q&A と内部限定確認事項をまとめる `未解決handoff` summary が表示されます。これは、いま見えている workspace 文脈を別の担当者へ read-only に渡すためのコピー補助です。通知、担当割当、SLA、ack、自動エスカレーション、状態更新を行うものではありません。

`未解決handoff` は internal user だけに表示されます。external user には handoff summary、内部限定確認事項、内部向け位置メモは表示されません。external user が見られる public Q&A の確認は、各文書・版の Q&A tab に閉じます。

summary に含まれる対象は次のとおりです。

- Q&A: 表示中 workspace の public Q&A thread のうち `open?` のもの
- 確認事項: 表示中 workspace の internal-only comment のうち `resolved?` ではないもの
- 検索中や投稿者 filter 中は、現在の `comment_q` / `comment_author_id` に一致して表示されているものだけ
- Q&A と確認事項は見出しを分け、状態、投稿者、版ラベル、位置メモ、短い本文 preview をコピー対象にする

copy 用 summary の URL は `comment_tab=unresolved` に戻り、現在有効な `comment_q` と `comment_author_id` だけを引き継ぎます。任意の `return_to`、`token`、`access_token`、別文書・別版への URL、外部 URL、anchor 指定は handoff URL に含めません。検索文脈がある場合は `文脈: 現在の検索/投稿者絞り込み適用中`、ない場合は `絞り込みなし` と読みます。

候補 0 件時の message は、未解決の Q&A や確認事項が「表示中の文書・版・検索文脈では」ないことを示します。問い合わせが存在しない保証、通知済み、回答済み、SLA 達成、ack 済みを意味しません。必要なら検索条件を解除し、`未解決` tab、`Q&A` tab、`確認事項` tabを確認してください。

## コメント検索の読み方

文書コメント workspace の `コメントを検索` は、現在表示できる Q&A / 確認事項の中からキーワードと投稿者で絞り込む補助機能です。キーワード検索は `comment_q` を使い、検索語は前後空白を取り除き、最大 100 文字までを current query として扱います。投稿者 filter は `comment_author_id` に User public_id を渡しますが、画面で選べる投稿者候補に含まれる author だけが有効な絞り込み条件になります。

絞り込みは、タブを切り替える前の元データに先に適用されます。絞り込み中に表示される Q&A 件数、確認事項件数、未解決件数、各タブの件数は、キーワードまたは投稿者条件に一致したコメントだけを基準に読みます。

投稿者 select の候補は、current user が表示できるコメント・返信の投稿者から最大 50 件まで表示されます。internal user は表示可能な Q&A、Q&A 返信、確認事項の投稿者を候補にできます。external user は表示可能な public Q&A と public reply の投稿者だけを候補にし、internal-only 確認事項や内部向け投稿者は候補・結果に出ません。

候補外、非表示、または存在しない author public_id が渡された場合、その値は投稿者 filter として採用されず、表示可能な全投稿者からの結果に戻ります。これは hidden author の存在確認に使うための filter ではなく、current user が画面上で見えている投稿者から探すための read-only 補助です。

絞り込み条件に一致するコメントがないタブでは、empty message の近くに `検索を解除してすべて表示` が表示されます。この link は `comment_q` と `comment_author_id` を外し、現在の `comment_tab` と既存 query context を維持したまま同じ workspace を読み直します。

検索フォーム内の `検索を解除` も同じくキーワードと投稿者 filter を外すための導線です。検索 0 件 message 近くの link は、結果を読んでいる位置から戻りやすくする補助であり、検索対象、件数計算、tab 構造、投稿・返信・状態更新後の戻り先文脈を変更するものではありません。

| 利用者 | 検索対象 | 表示されるタブへの効き方 |
| --- | --- | --- |
| internal user | Q&A root の本文・投稿者名・版ラベル、表示可能な Q&A 返信の本文・投稿者名、確認事項の本文・投稿者名・版ラベル・位置メモ。投稿者 filter は表示可能な Q&A / 返信 / 確認事項の author に一致する root thread または確認事項を残す | `すべて` / `Q&A` / `確認事項` / `未解決` の各タブに先に絞り込みが効く |
| external user | 自分に表示される public Q&A root の本文・投稿者名・版ラベル、表示可能な public reply の本文・投稿者名。投稿者 filter は表示可能な public Q&A / reply の author に一致する public thread だけを残す | `すべて` / `Q&A` / `未解決Q&A` の各タブに先に絞り込みが効く |

作者名の部分一致は、コメント本文や位置メモと同じ `comment_q` の検索対象です。投稿者 select は author public_id を使う専用 filter で、表示可能な投稿者候補から 1 人を選ぶと、その人が root または visible reply の投稿者である Q&A thread、またはその人が投稿者である確認事項に絞り込まれます。

版ラベル検索は、版に紐づく Q&A root または確認事項を探す入口です。返信は parent と同じ文書・版に紐づきますが、検索対象としては visible reply の本文と投稿者名を見ます。版ラベルや投稿者 filter を指定したときに、版に紐づく public Q&A や internal-only 確認事項が current user の可視範囲内で残るかを確認してください。

external user には internal-only の確認事項、internal-only Q&A、内部向け確認事項の投稿者名や位置メモは表示されず、検索結果にも出ません。絞り込み中に `絞り込み条件に一致するQ&Aはありません` と表示される場合でも、internal-only の存在を示す意味ではありません。

現時点では、saved search、pagination、投稿者 remote search、通知、SLA、回答期限、自動エスカレーションは current support として扱いません。

## 操作後の戻り先文脈

コメント検索中、投稿者 filter 中、または `Q&A` / `確認事項` / `未解決` などのタブ表示中に投稿・返信・状態更新を行う場合、フォームと操作ボタンは現在の `comment_tab`、検索中のみ `comment_q`、有効な投稿者 filter 中のみ `comment_author_id` を送信します。操作後は controller が許可済みの `comment_tab` / `comment_q` / `comment_author_id` だけを current document / version の workspace path に復元します。

| 操作 | 維持される文脈 | 読み方 |
| --- | --- | --- |
| Q&A 投稿 / 確認事項追加 | 現在の `comment_tab`、検索中の `comment_q`、有効な `comment_author_id` | 作成後も同じ検索語・投稿者・タブで workspace を読み直す |
| Q&A 返信 | 現在の `comment_tab`、検索中の `comment_q`、有効な `comment_author_id` | 返信先 thread の visibility は parent と同じまま、表示可能な範囲の検索・投稿者・タブ文脈へ戻る |
| `回答済みにする` / `クローズする` | 現在の `comment_tab`、検索中の `comment_q`、有効な `comment_author_id` | Q&A 状態更新後も、表示可能な Q&A の中で同じ検索・投稿者・タブ文脈を維持する |
| 確認事項の `解決` | 現在の `comment_tab`、検索中の `comment_q`、有効な `comment_author_id` | internal user が見られる確認事項だけを対象に、操作後も同じ文脈へ戻る |

`comment_tab` は controller 側の許可リストにない値なら既定タブへ戻します。`comment_q` は検索と同じく正規化され、空文字や検索していない状態では復元対象にしません。`comment_author_id` は current user が表示できる author の public_id だけを復元対象にし、候補外や hidden author の public_id は戻り先に残しません。任意の `return_to` URL、別文書・別版への戻り先、外部 URL、anchor 指定はこの flow では扱いません。

external user の戻り先文脈は、表示可能な public Q&A の範囲に閉じます。internal-only の確認事項、内部向け位置メモ、internal user 向け投稿者情報へ誘導するものではありません。

## internal-only の境界

- external user は internal-only の確認事項を閲覧できません。
- external user は `note` / `issue` / `request_change` として投稿できません。
- public Q&A への返信は、internal user が投稿しても public thread として保存されます。
- internal-only の確認事項へ external user が返信する運用はありません。

外部に見せる必要がある補足は Q&A に残し、社内だけで扱う指摘・修正依頼・位置メモは確認事項に分けます。

## 管理者の解決操作

admin は open Q&A thread に表示される `回答済みにする` / `クローズする` から、Q&A の状態を進められます。

- `回答済みにする` は `status: resolved` にし、`resolved_by` と `resolved_at` を更新します。回答・対応が済んだ質問に使います。
- `クローズする` は `status: rejected` にし、`resolved_by` と `resolved_at` は持たせません。対応しない質問、受付を閉じたい質問、これ以上の回答を続けない質問に使います。
- 検索中、投稿者 filter 中、またはタブ表示中に操作した場合は、現在の `comment_tab`、検索中の `comment_q`、有効な `comment_author_id` を維持した workspace へ戻ります。
- どちらの操作も Q&A thread の状態ラベルを変えるための current UI です。通知、メール送信、SLA、期限管理、エスカレーションを発火するものとして扱わないでください。

確認事項（社内レビューコメント）は admin が `解決` を付けられます。`解決` は `status: resolved`、`resolved_by`、`resolved_at` を更新します。検索中、投稿者 filter 中、またはタブ表示中に操作した場合は、同じ `comment_tab` / `comment_q` / `comment_author_id` 文脈へ戻ります。確認事項側の却下 workflow や、Q&A と確認事項を横断する状態設計はこの runbook では扱いません。

## 後続 issue との境界

この節は、runbook 本文が説明している current support と、後続 queue / historical docs follow-up を読み分けるためのメモです。以下の issue は、本文にある現在の Q&A / 確認事項 / 検索 / 戻り先文脈を変更済みの仕様として追加するものではありません。

- historical / completed docs follow-up: `#1121` はこの runbook の追加、`#2298` は `comment_q` 検索、`#3044` は操作後の `comment_tab` / `comment_q` 復元、`#3519` は検索 0 件 empty state の `検索を解除してすべて表示` 導線、`#3518` は投稿者 filter を docs-only で同期したものです。本文の current behavior はこれらの完了済み docs follow-up を反映しています。
- completed dashboard handoff: `#3024` は dashboard に `受付中Q&A候補` を追加した runtime / UI first slice、`#3025` と `#3809` はその docs-only 追従です。本文では dashboard の短い read-only handoff と、既存 Q&A workspace へ戻る current behavior だけを扱います。
- completed workspace handoff: `#3208` は未解決 Q&A / 確認事項を workspace 内で read-only handoff しやすくする feature slice、`#3793` はその docs-only 追従です。本文では internal user 向けの `未解決handoff` summary、`comment_q` / `comment_author_id` 文脈、external user 非表示、通知・担当割当・SLA 非対象の境界だけを扱います。
- historical / completed behavior boundary: `#1118` はコメント UI の視認性改善、`#1119` は回答済み / クローズ操作の UX 整理、`#1257` は Q&A の未解決タブ境界です。現在の runbook では画面上のタブ、状態ラベル、admin 操作の読み方だけを扱います。
- active / future quality guard: `#3515` は unsupported decision、admin-only update、visibility 境界を request spec で固定する quality queue です。runbook 本文は現在の操作の読み方に閉じ、controller / model の状態更新仕様をここで変更しません。
- completed design cue: `#3516` は Q&A と internal-only 確認事項の status / visibility cue を見分けやすくする design queue です。本文では merge 済みの表示範囲 cue だけを current UI として扱い、badge / card layout / workflow 再設計は current support として扱いません。

## 確認に使う主な実装

- `DocumentReviewComment`: `comment_type`、`status`、`internal_only`、`parent_id`、`document_version_id`、`visible_to`、`public_thread?`、`qa_status_label`、`resolve!`
- `DashboardController`: internal user 向け `open_question_handoff_threads`、`OPEN_QA_HANDOFF_LIMIT = 5`、accessible document scope、open public Q&A root だけを dashboard 候補にする境界
- `DocumentReviewCommentsController`: create / update 後の `comment_tab` / `comment_q` / `comment_author_id` 復元、create 時の visibility 補正、external user の Q&A 制約、admin の `resolve` / `reject` 操作と notice
- `DocumentCommentWorkspaceSearch`: `comment_q` の 100 文字上限、`comment_author_id` の visible author 候補、投稿者候補最大 50 件、Q&A / 確認事項の検索対象、投稿者名・版ラベル・位置メモの current search fields、current user の可視範囲内に閉じた filtering
- `DocumentCommentWorkspaceTab`: 許可済み `comment_tab` と、無効な tab を既定表示へ戻す境界
- `app/views/dashboard/show.html.erb`: internal user 向け `受付中Q&A候補`、文書 / 案件 / 版 / 投稿者 / 返信有無 / 最終活動 / 本文 preview、候補 0 件時の non-SLA copy、external user 非表示境界
- `app/views/documents/_comment_workspace.html.slim`: `質問する` と `確認事項を残す` の入力欄、コメント検索、投稿者 select、絞り込み中の件数 cue、検索 0 件時の復帰 link、Q&A / 確認事項 / 未解決タブ、投稿時に渡す workspace 文脈
- `app/views/documents/_comment_workspace_handoff_summary.html.slim`: internal user 向け `未解決handoff` summary、`comment_q` / `comment_author_id` の allowlist URL、Q&A と内部限定確認事項のコピー用見出し、0 件 message、通知・担当割当・SLA 非対象 copy
- `app/views/documents/_comment_workspace_threads.html.slim`: thread 表示、返信欄、版ラベル、Q&A の `回答済みにする` / `クローズする`、確認事項の位置表示と `解決`、検索 0 件時の復帰 link、返信・状態更新時に渡す workspace 文脈
- `spec/requests/dashboard_open_question_handoff_spec.rb`: dashboard の open public Q&A root 候補、resolved / rejected / internal-only / archived document 除外、external user 非表示、候補 0 件時の non-SLA copy
- `spec/requests/document_comment_workspace_handoff_spec.rb`: internal user 向け handoff summary、external user 非表示、検索文脈、resolved / closed 除外、secret-like query 非表示
- `spec/requests/document_comment_workspace_search_cue_spec.rb`: 検索中の件数・タブ cue、external user で internal-only 確認事項が露出しないこと
- `spec/requests/document_comment_workspace_search_fields_spec.rb`: 作者名・版ラベル検索、投稿者 filter、external user の visible Q&A / visible reply に閉じた検索範囲
- `spec/requests/document_comment_workspace_empty_search_spec.rb`: 検索 0 件時の `検索を解除してすべて表示` link、`comment_q` / `comment_author_id` 解除、`comment_tab` と既存 query context 維持、external user に internal-only 確認事項を示唆しない境界
- `spec/requests/document_comment_workspace_visibility_cues_spec.rb`: Q&A / 確認事項の表示範囲 cue、Q&A 状態と確認事項状態の読み分け、external user に internal-only 文言や内容を出さない境界
- `spec/requests/document_review_comment_redirect_context_spec.rb`: create / reply / status update 後の `comment_tab` / `comment_q` 復元境界と、無効 tab / 正規化済み検索語の扱い
