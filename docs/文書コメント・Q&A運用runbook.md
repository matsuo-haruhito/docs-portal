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

## コメント検索の読み方

文書コメント workspace の `コメントを検索` は、現在表示できる Q&A / 確認事項の中から `comment_q` で絞り込む補助機能です。検索語は前後空白を取り除き、最大 100 文字までを current query として扱います。

検索は、タブを切り替える前の元データに先に適用されます。検索中に表示される Q&A 件数、確認事項件数、未解決件数、各タブの件数は、検索条件に一致したコメントだけを基準に読みます。

| 利用者 | 検索対象 | 表示されるタブへの効き方 |
| --- | --- | --- |
| internal user | Q&A root の本文・投稿者名・版ラベル、表示可能な Q&A 返信の本文・投稿者名、確認事項の本文・投稿者名・版ラベル・位置メモ | `すべて` / `Q&A` / `確認事項` / `未解決` の各タブに先に検索が効く |
| external user | 自分に表示される public Q&A root の本文・投稿者名・版ラベル、表示可能な public reply の本文・投稿者名 | `すべて` / `Q&A` / `未解決Q&A` の各タブに先に検索が効く |

作者名検索は、投稿者名そのものを直接見るための専用 filter ではなく、コメント本文や位置メモと同じ `comment_q` の部分一致です。internal user は Q&A と確認事項の投稿者名を探せますが、external user は表示可能な public Q&A と返信の投稿者名だけを探せます。

版ラベル検索は、版に紐づく Q&A root または確認事項を探す入口です。返信は parent と同じ文書・版に紐づきますが、検索対象としては visible reply の本文と投稿者名を見ます。版ラベルを指定したときに、版に紐づく public Q&A や internal-only 確認事項が current user の可視範囲内で残るかを確認してください。

external user には internal-only の確認事項、internal-only Q&A、内部向け確認事項の投稿者名や位置メモは表示されず、検索結果にも出ません。検索中に `検索条件に一致するQ&Aはありません` と表示される場合でも、internal-only の存在を示す意味ではありません。

現時点では、saved search、pagination、検索専用の作者 filter、通知、SLA、回答期限、自動エスカレーションは current support として扱いません。

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
- どちらの操作も Q&A thread の状態ラベルを変えるための current UI です。通知、メール送信、SLA、期限管理、エスカレーションを発火するものとして扱わないでください。

確認事項（社内レビューコメント）は admin が `解決` を付けられます。`解決` は `status: resolved`、`resolved_by`、`resolved_at` を更新します。確認事項側の却下 workflow や、Q&A と確認事項を横断する状態設計はこの runbook では扱いません。

## 後続 issue との境界

- `#1118`: コメント UI の視認性改善。runbook では現在表示されるタブやラベルの読み方だけを扱います。
- `#1119`: 回答済み / クローズ操作の UX 整理。current UI では admin が open Q&A を `回答済み` または `クローズ` へ進められる前提で読みます。
- `#1257`: Q&A の未解決タブ境界。`クローズ` 済み Q&A を未解決扱いに残すかどうかの contract はこの issue / 対応 PR 側で確認します。
- `#1121`: この runbook の docs-only 追加。runtime code、view、controller、model、spec は変更しません。
- `#2298`: 文書コメント検索の検索中 cue、作者名・版ラベル検索、external user の internal-only 非露出境界をこの runbook へ追従します。runtime code、view、controller、model、spec は変更しません。

## 確認に使う主な実装

- `DocumentReviewComment`: `comment_type`、`status`、`internal_only`、`parent_id`、`document_version_id`、`visible_to`、`public_thread?`、`qa_status_label`、`resolve!`
- `DocumentReviewCommentsController`: create 時の visibility 補正、external user の Q&A 制約、admin の `resolve` / `reject` 操作と notice
- `DocumentCommentWorkspaceSearch`: `comment_q` の 100 文字上限、Q&A / 確認事項の検索対象、投稿者名・版ラベル・位置メモの current search fields、current user の可視範囲内に閉じた filtering
- `app/views/documents/_comment_workspace.html.slim`: `質問する` と `確認事項を残す` の入力欄、コメント検索、検索中の件数 cue、Q&A / 確認事項 / 未解決タブ
- `app/views/documents/_comment_workspace_threads.html.slim`: thread 表示、返信欄、版ラベル、Q&A の `回答済みにする` / `クローズする`、確認事項の位置表示と `解決`
- `spec/requests/document_comment_workspace_search_cue_spec.rb`: 検索中の件数・タブ cue、external user で internal-only 確認事項が露出しないこと
- `spec/requests/document_comment_workspace_search_fields_spec.rb`: 作者名・版ラベル検索、external user の visible Q&A / visible reply に閉じた検索範囲
