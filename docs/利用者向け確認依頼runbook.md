# 利用者向け確認依頼runbook

この runbook は、`DocumentApprovalRequest` の一覧・詳細を current UI に沿って読むための運用メモです。

新しい確認ポリシーや通知仕様はここでは定義しません。確認依頼を作る入口、案件横断一覧、文書配下一覧、詳細で見える項目、`OK` / `Cancel` 後の戻り方を、current controller / view の挙動に合わせて整理します。dashboard 上の導線全体の役割差は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md) を参照してください。

## 先に見るもの

1. 確認依頼を含む日常導線の全体像は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md)
2. 文書詳細で依頼を作る前後の文書閲覧 flow は [閲覧画面とUI](./specs/閲覧画面とUI.md)
3. internal user / requester / external user の権限前提は [基本モデルと権限](./specs/基本モデルと権限.md)

## 入口

- 文書詳細の `正式な確認依頼` セクションから、`タイトル` `確認相手` `内容` を入力して依頼を作成する
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

## 操作と戻り方

- internal user は pending の detail で `OK` を押せる
- pending の detail では、internal user または依頼者本人が `Cancel` を押せる
- `OK` / `Cancel` の実行後は同じ detail へ戻る
- 一覧の `依頼名` link から detail に入った場合、`一覧へ戻る` は元の一覧 URL へ戻る
- `対応待ち` / `OK済み` / `Cancel済み` filter をかけていた場合も、`return_to` により同じ filter 条件へ戻れる
- `依頼を検索`、`依頼者`、`確認相手` の条件をかけていた場合も、detail への link は current 一覧 URL を `return_to` として渡すため、一覧へ戻ると同じ探索文脈に戻れる。検索語は正規化後の最大 100 文字として戻り先に残ります
- detail へ直接入った場合の fallback は、internal user なら全体一覧、internal user 以外なら対象文書 detail になる
- `return_to` は `/` 始まりで `//` ではない path だけを使い、外部 URL のような unsafe value は fallback に戻す

## 迷ったときの切り分け

- 未処理の確認依頼だけを先に見たい: dashboard の `保留中の確認依頼` または一覧の `対応待ち` filter から入る
- 自分が依頼したものを見直したい: `依頼者` filter で自分または対象 requester を選び、必要なら `対応待ち` / `OK済み` / `Cancel済み` を足す
- 自分宛または特定担当者に溜まっているものを見たい: `確認相手` filter を使い、pending だけなら `対応待ち` も併用する
- 依頼名、本文、文書名、slug、関係者名から探したい: `依頼を検索` に 100 文字以内の特徴的な断片を入れる。長い本文や複数条件を一度に貼るより、status / requester / approver filter と組み合わせる
- 対象文書を見直してから対応したい: 一覧の `文書名` link で文書詳細へ戻る
- 誰がいつ対応したかを確認したい: detail の `対応者` `OK日時` `Cancel日時` を見る
- 依頼者本人が依頼を取り下げたい: pending の detail で `Cancel` を使う
- 文書詳細へ戻るべきか一覧へ戻るべきか迷う: 一覧から入った detail では `一覧へ戻る`、文書本文を見直したいときは breadcrumb の文書 link を使う

## 関連コード

- `config/routes.rb`
- `app/controllers/document_approval_requests_controller.rb`
- `app/views/document_approval_requests/index.html.slim`
- `app/views/document_approval_requests/show.html.slim`
- `app/views/documents/_detail_sections.html.slim`
