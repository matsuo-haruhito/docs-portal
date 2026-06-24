# 利用者向け確認依頼runbook

この runbook は、`DocumentApprovalRequest` の一覧・詳細を current UI に沿って読むための運用メモです。

新しい確認ポリシーや通知仕様はここでは定義しません。確認依頼を作る入口、案件横断一覧、文書配下一覧、詳細で見える項目、`OK` / `Cancel` 後の戻り方を、current controller / view の挙動に合わせて整理します。dashboard 上の導線全体の役割差は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md) を参照してください。

ここで扱う確認依頼は、文書に紐づく軽量な確認依頼の current flow です。画面上に `正式な確認依頼` と出る場合でも、正式レビュー承認 workflow の採否、承認者 chain、通知、SLA、段階承認、公開承認 policy を定義するものではありません。workflow 全体へ広げる必要が出た場合は [正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md) に戻します。

## 先に見るもの

1. 確認依頼を含む日常導線の全体像は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md)
2. 文書詳細で依頼を作る前後の文書閲覧 flow は [閲覧画面とUI](./specs/閲覧画面とUI.md)
3. internal user / requester / external user の権限前提は [基本モデルと権限](./specs/基本モデルと権限.md)
4. 確認依頼と正式レビュー承認 workflow の境界は [正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md)

## 入口

- 文書詳細の `正式な確認依頼` セクションから、`タイトル` `確認相手` `内容` を入力して依頼を作成する
- この `正式な確認依頼` セクションは、DocumentApprovalRequest を作る current UI の入口です。多段承認、通知、SLA、公開承認 state machine を開始する入口として読まない
- 作成後は確認依頼 detail へ移動し、`return_to` には作成元の文書詳細が渡される
- internal user は `GET /document_approval_requests` の全体一覧で、案件横断の確認依頼を見直せる
- 文書配下の `GET /projects/:project_code/documents/:document_slug/document_approval_requests` では、対象文書に閉じた確認依頼を見直せる
- 依頼者本人は、自分が作成した依頼の detail を閲覧でき、pending の間だけ `Cancel` できる

## 一覧で見る項目

一覧では、まず件数と status filter を見ます。

- `対応待ち`: `pending` の依頼。internal user が `OK` でき、internal user または依頼者本人が `Cancel` できる
- `OK済み`: `approved` の依頼。対応者と `OK日時` を detail で確認する
- `Cancel済み`: `cancelled` の依頼。対応者と `Cancel日時` を detail で確認する
- `すべて`: status を絞らず、`対応待ち` と `処理済み` の section に分けて確認する

`OK済み` は依頼単位の確認が済んだことを示す status です。顧客承認済み、法務承認済み、公開承認済み、正式 workflow 完了済みを自動的には意味しません。

状態ボタンの件数は一覧全体の件数です。検索語、依頼者、確認相手、status filter を使っている場合は、画面の `表示中条件` と各 section の `N件（表示中条件内）` を見て、現在の条件を反映した件数として読みます。filter がない場合の section 件数は `N件（一覧全体）` と表示され、全体一覧の section 件数として読めます。

一覧上部の検索条件は、status filter と併用して使います。

- `依頼を検索`: 依頼名、本文、文書名、slug、依頼者名、確認相手名をまとめて探す free-text 条件です。検索語は前後の空白を落としてから最大 100 文字まで適用されます
- `依頼者`: 自分が依頼したもの、または特定の requester から出ている依頼を見直す条件です
- `確認相手`: 特定担当者に指名された依頼、または担当者別に溜まっている pending を見直す条件です
- `検索条件` の summary は、free-text、依頼者指定、確認相手指定のうち現在効いている条件と表示件数を短く読み返す入口です
- `検索を解除` は free-text だけを外し、依頼者 / 確認相手 filter と status filter は残します
- `担当者絞り込みを解除` は依頼者 / 確認相手 filter を外し、free-text と status filter は残します

検索欄の placeholder は `依頼名・本文・文書名・slug・関係者名` です。画面には `検索語は最大100文字です。依頼名・本文・文書名・slug・関係者名の断片で探せます。` と表示されます。長い本文や依頼名をそのまま貼るのではなく、特徴的な 100 文字以内の断片で探すと、status / requester / approver filter と組み合わせても意図した条件を読み返しやすくなります。

0 件時は次のように切り分けます。

- `条件に一致する確認依頼はありません。` は、status、free-text、依頼者、確認相手のいずれかの条件で 0 件になった状態です
- 0 件メッセージ近くの `すべての確認依頼を見る` は、status、free-text、依頼者、確認相手をすべて外し、全体一覧または文書配下一覧の先頭へ戻る導線です
- 0 件メッセージ近くの `検索を解除` は、フォーム上部の同名 link と同じく free-text だけを外し、status と担当者条件は維持します
- 0 件メッセージ近くの `担当者絞り込みを解除` は、依頼者 / 確認相手 filter だけを外し、status と free-text は維持します
- 担当者条件だけで 0 件になっている場合も同じ empty state になり、担当者絞り込みの見直しを先に疑います
- free-text が長い場合は、前後の空白を落とした最大 100 文字だけが検索に使われます。検索対象を変えたいときは、より短い依頼名・本文・文書名・slug・関係者名の断片へ絞ります
- `確認依頼はありません。` は、filter を掛けていない状態で確認依頼レコード自体がまだ無い状態です

一覧の列は次の順に読みます。

| 列 | 見方 |
| --- | --- |
| 日時 | 依頼が作成された日時 |
| 文書名 | 対象文書への link。文書本文や版を確認したいときに使う |
| 依頼名 | 確認依頼 detail への link。current 一覧 URL が `return_to` として渡される |
| 依頼者 | 確認を依頼した user |
| 確認相手 | 指名された確認相手。未設定の場合は `-` |
| 状態 | `対応待ち` / `OK済み` / `Cancel済み` の現在状態 |

## detail で見る項目

確認依頼 detail では、一覧だけでは分からない対応履歴を確認します。

- `状態`: 現在の status
- `依頼者`: 依頼を作成した user
- `確認相手`: 指名された user。未設定なら `-`
- `対応者`: `OK` または `Cancel` を実行した user。未処理なら `-`
- `OK日時`: `OK` 済みの場合の日時。未処理または Cancel の場合は `-`
- `Cancel日時`: Cancel 済みの場合の日時。未処理または OK の場合は `-`
- `内容`: 依頼作成時の本文がある場合だけ表示される
- `対応済み`: `OK済み` または `Cancel済み` の detail だけに出る summary。状態、対応者、対応日時を table より先に読み直す入口として使う

Cancel 理由の入力・保存・表示は current support ではありません。Cancel 済み detail では、理由ではなく `対応者` と `Cancel日時` を確認します。

## 操作と戻り方

- pending の detail には `操作` セクションがあり、処理 action と戻り action が group ごとに分かれている
- internal user は `OKする` group の説明を読み、内容を確認済みにする場合だけ `OK` を押す
- requester 本人には `OKする` group は表示されず、自分が作成した pending 依頼の `Cancelする` group だけを使える
- pending の detail では、internal user または依頼者本人が `Cancelする` group から `Cancel` を押せる
- `Cancelする` group の説明どおり、current UI では理由入力や通知の追加は行わない
- `OK` / `Cancel` の実行後は同じ detail へ戻り、`対応済み` summary と `対応者` / `OK日時` / `Cancel日時` を確認する
- 処理済み detail には pending action は出ない。再度 `OK` / `Cancel` する導線として読まない
- 一覧の `依頼名` link から detail に入った場合、`一覧へ戻る` group の `一覧へ戻る` は元の一覧 URL へ戻る
- `対応待ち` / `OK済み` / `Cancel済み` filter をかけていた場合も、`return_to` により同じ filter 条件へ戻れる
- `依頼を検索`、`依頼者`、`確認相手` の条件をかけていた場合も、detail への link は current 一覧 URL を `return_to` として渡すため、一覧へ戻ると同じ探索文脈に戻れる。検索語は正規化後の最大 100 文字として戻り先に残ります
- detail へ直接入った場合の fallback は、internal user なら全体一覧、internal user 以外なら対象文書 detail になる
- `return_to` は `/` 始まりで `//` ではない path だけを使い、外部 URL のような unsafe value は fallback に戻す

## 迷ったときの切り分け

- 未処理の確認依頼だけを先に見たい: dashboard の `保留中の確認依頼` または一覧の `対応待ち` filter から入る
- 自分が依頼したものを見直したい: `依頼者` filter で自分または対象 requester を選び、必要なら `対応待ち` / `OK済み` / `Cancel済み` を足す
- 自分宛または特定担当者に溜まっているものを見たい: `確認相手` filter を使い、pending だけなら `対応待ち` も併用する
- 依頼名、本文、文書名、slug、関係者名から探したい: `依頼を検索` に 100 文字以内の特徴的な断片を入れる。長い本文や複数条件を一度に貼るより、status / requester / approver filter と組み合わせる
- 絞り込み結果が 0 件になった: いったん全条件を外すなら `すべての確認依頼を見る`、検索語だけを外すなら `検索を解除`、担当者条件だけを外すなら `担当者絞り込みを解除` を 0 件メッセージ近くで使う
- 状態ボタンの件数と section 件数が違って見える: 状態ボタンは一覧全体、`N件（表示中条件内）` は現在の検索語・担当者条件・status を反映した section 件数として読む
- 対象文書を見直してから対応したい: 一覧の `文書名` link で文書詳細へ戻る
- 誰がいつ対応したかを確認したい: detail の `対応済み` summary または `対応者` `OK日時` `Cancel日時` を見る
- 依頼者本人が依頼を取り下げたい: pending の detail で `Cancelする` group を使う。current UI では Cancel 理由は残らない
- 文書詳細へ戻るべきか一覧へ戻るべきか迷う: 一覧から入った detail では `一覧へ戻る`、文書本文を見直したいときは breadcrumb の文書 link を使う
- 確認依頼を正式レビュー承認 workflow、公開承認、送付承認へ広げたい: この runbook では決めず、[正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md) に戻して human decision として扱う

## 関連コード

- `config/routes.rb`
- `app/controllers/document_approval_requests_controller.rb`
- `app/views/document_approval_requests/index.html.slim`
- `app/views/document_approval_requests/show.html.slim`
- `app/views/documents/_detail_sections.html.slim`
- `spec/requests/document_approval_request_empty_state_links_spec.rb`
- `spec/requests/document_approval_request_section_count_cues_spec.rb`
- `spec/requests/document_approval_requests_spec.rb`
