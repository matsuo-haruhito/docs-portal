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
- detail へ直接入った場合の fallback は、internal user なら全体一覧、internal user 以外なら対象文書 detail になる
- `return_to` は `/` 始まりで `//` ではない path だけを使い、外部 URL のような unsafe value は fallback に戻す

## 迷ったときの切り分け

- 未処理の確認依頼だけを先に見たい: dashboard の `保留中の確認依頼` または一覧の `対応待ち` filter から入る
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
