# 利用者向けアクセス申請runbook

この runbook は、利用者が `GET /access_requests` で自分の申請状況を見返すときの current UI をまとめる。

新しい申請ポリシーや承認基準はここでは定義しない。current 実装を前提に、dashboard の `保留中の申請` から入ったあとに何を見て、pending の申請をいつ取り消すかを整理する。

## 先に見るもの

1. dashboard から入る個人導線の全体像は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md)
2. 権限や利用者種別の前提は [基本モデルと権限](./specs/基本モデルと権限.md)
3. internal 管理者が申請を裁く側の画面は [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md)
4. 同意前提や利用者向け文面の前提は [利用規約・秘密保持の同意管理](./利用規約・秘密保持の同意管理.md)

## 1. どこから入るか

`GET /access_requests` は、current user 自身が送信したアクセス申請を時系列で見返す一覧です。

- dashboard の `保留中の申請` summary card から `申請一覧へ` で入る
- dashboard 本体の `保留中のアクセス申請` では、current user 自身の pending 申請のうち最近の最大 3 件だけを概要確認できる
- 一覧に出るのは current user 自身が requester の申請だけで、internal 管理者向けの `admin/access_requests` とは別画面
- 画面の役割は「送信済み申請の状態確認」と「pending の申請取消」に閉じている
- 新しい申請はこの一覧で作るのではなく、案件・文書・ファイル側でアクセス不足に応じて送信する current flow を前提にする

dashboard とのつながり:

- summary card の `保留中の申請` 件数は pending の申請数を見るための入口
- dashboard 本体では pending 申請の対象、要求権限、状態、申請日時を確認し、詳細な取消や過去申請の確認は一覧へ進む
- pending が 0 件のときも、一覧へ入ると pending 以外の processed request を recent first で見返せる

## 2. 一覧の見方

一覧 table では `対象` `要求権限` `状態` `理由` `承認者` を見ます。

### 対象

- `Project` `Document` `DocumentFile` のどれに対する申請かを先頭で見分ける
- 2 行目には対象名が出る
- project なら案件名、document なら文書名、file ならファイル名を優先し、名前が無いときは public id を fallback として見る

### 要求権限

- current 申請で求めている access level を確認する列
- 同じ対象に複数の申請が並ぶときは、まずこの列で何を求めた申請かを切り分ける

### 状態

- current 一覧では `pending` `approved` `rejected` `cancelled` のいずれかとして扱う
- まず pending かどうかを見て、まだ相手側の処理待ちなのか、すでに結果が出た申請なのかを切り分ける

### 理由

- 申請送信時に保存された理由を見返す列
- この一覧は理由を編集する画面ではなく、送信済みの内容確認に使う

### 承認者

- 処理済みの申請では approver のメールアドレスが入る
- まだ誰も処理していない行は `-` のままになる

## 3. `取消` の使いどころ

- `取消` ボタンが出るのは pending の申請だけ
- まだ処理される前に「この申請は不要になった」と判断したときに使う
- `取消` 後は一覧へ戻り、notice を見ながら状態変化を確認する
- approved / rejected / cancelled の行には `取消` ボタンは出ない

判断の目安:

- 対象や要求権限を見直して、別の申請として出し直したいときは、まず pending を取り消してから対象画面側で送り直す
- すでに処理済みの申請は、この一覧から内容変更せず結果確認だけに留める

## 4. empty state の読み方

- `送信済みのアクセス申請はありません。` は、current user がまだ 1 件も申請していない状態を示す
- dashboard の `保留中のアクセス申請はありません。` は、current user に pending の申請がない状態を示す
- pending の summary card 件数が 0 でも、この一覧には approved / rejected / cancelled の過去申請が残りうる
- 一覧が空なら、まず「まだ送っていない」のか「別対象でのアクセス不足を解消したかったのか」を切り分ける

## 迷ったときの切り分け

- 自分の pending request を見返したい: この runbook を正本にする
- internal 管理者として申請を承認 / 却下したい: [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md) を見る
- 権限モデル自体を確認したい: [基本モデルと権限](./specs/基本モデルと権限.md) を見る
- 同意画面や利用者向け同意導線まで含めて確認したい: [利用規約・秘密保持の同意管理](./利用規約・秘密保持の同意管理.md) を見る

## 関連画面

- `app/views/dashboard/show.html.erb`
- `app/views/access_requests/index.html.slim`
- `app/controllers/access_requests_controller.rb`
- `config/routes.rb`
