# company_master_admin会社・ユーザー管理runbook

この runbook は、`company_master_admin` が current `main` で使える管理画面と、使えない管理画面の境界をまとめる。

新しい権限方針はここでは定義しない。current code、request spec、既存仕様 docs を前提に、日常運用でどこを見て、どこから先は internal admin へ引き継ぐかを整理する。

## 先に見るもの

1. role の正本は [基本モデルと権限](./specs/基本モデルと権限.md)
2. internal admin 向けの広い管理 runbook は [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md) や [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md)

## role の要約

`company_master_admin` は、社外ユーザー系の閲覧境界を保ったまま、自社の `会社` と `ユーザー` だけを管理できる role。

current `main` の前提:

- 他社の `会社` や `ユーザー` は見えない
- `案件` `文書` `文書権限` `監査ログ` `利用状況` などの admin surface には入れない
- 文書閲覧権限は `external` と同じ制約に従い、admin 相当の全文書閲覧は持たない

## 入口と current flow

current `main` では、`/admin` へ入ると `Admin::DashboardController` が `会社` 一覧 (`/admin/companies`) へ redirect する。

その後は role-aware な nav で `会社` と `ユーザー` だけが表示されるため、日常運用では次の flow を入口として使う。

- `/admin` から入って `会社` 一覧へ着地する
- nav から `ユーザー` へ移動する
- それ以外の admin surface が必要になったら internal admin へ引き継ぐ

## 1. 会社画面でできること

`/admin/companies` では、自社の会社マスタだけを一覧・更新できる。

current `main` で確認できること:

- 一覧には自社の会社だけが出る
- 自社の `domain` `name` `active` は更新できる
- 他社の会社更新は `not_found` になる
- 会社の新規作成は `forbidden` になる

使いどころ:

- 自社会社名やドメイン表記の修正
- 自社会社の active 状態の見直し

internal admin へ戻すもの:

- 他社会社の修正
- 会社の新規登録や削除方針の判断
- 案件や文書の管理と一緒に行う調整

## 2. ユーザー画面でできること

`/admin/users` では、自社に所属するユーザーだけを一覧・更新・追加できる。

current `main` で確認できること:

- 一覧には自社ユーザーだけが出る
- 表示中の範囲にユーザーが 0 件のときは、空 table ではなく `ユーザー一覧` の empty state が出る
- 0 件時は上の `新規登録` card から、メールアドレスと必要な項目を入れて最初の 1 件を作る
- 他社ユーザーの edit は `not_found` になる
- 自社ユーザーの `name` や `active` は更新できる
- `company_master_admin` が見る form では、`ユーザー種別` は `external` 固定、`会社` は自社固定の read-only 表示になる
- form で `internal` や他社 `company_id` を送っても、保存時には `external` / 自社所属へ矯正される
- 新規作成も自社所属の `external` user として保存される

使いどころ:

- 自社ユーザーがまだいないときの最初の登録
- 自社ユーザーの有効化・無効化
- 自社ユーザー名やメールアドレスの保守
- 自社メンバーの追加

internal admin へ戻すもの:

- user type を `internal` へ変える相談
- 他社所属ユーザーの調整
- 案件所属や文書権限まで含む広いアクセス設計

## 3. company 管理者フォームの見え方

`company_master_admin` が `ユーザー` の新規登録や編集を開くと、current `main` では保存結果に沿った fixed 表示を先に見せる。

見分け方:

- `ユーザー種別` は選択肢ではなく、`external` 固定の表示として見える
- `会社` も選択肢ではなく、自社名の固定表示として見える
- `name` `email_address` `active` `password` `password_confirmation` は通常どおり入力・更新する
- 補足 copy でも「会社管理者から登録するユーザーは、所属会社とユーザー種別が自動で固定される」と案内される

意味合い:

- 画面上で `internal` や他社所属を選べないように見せつつ、server-side の保存契約とも矛盾しないようにしている
- role を広げたのではなく、もともとの保存矯正ルールを UI でも読み取りやすくした current state と考える

## 4. 入れない管理画面

current request spec で `company_master_admin` が forbidden として固定されている主な画面は次のとおり。

- `案件`
- `文書`
- `文書権限`
- `監査ログ`
- `利用状況`

意味合い:

- `company_master_admin` は company / user master の最小管理 role であり、案件運用や公開制御の role ではない
- 文書閲覧や添付ダウンロードは、管理画面ではなく通常の project / document 側の権限で判断される

## 5. 文書閲覧境界の見方

`company_master_admin` の閲覧権限は `external` と同じルールで決まる。

- `ProjectMembership` がない案件は見えない
- `DocumentPermission` が必要な文書は、許可がない限り見えない
- `internal_only` 文書は company master でも閲覧できない
- 添付ファイル download は `download` 権限が必要

つまり、`会社` と `ユーザー` を管理できても、文書閲覧の範囲は internal admin より広がらない。

## 日常運用の見分け方

- 自社会社情報を直したい: `会社`
- 自社ユーザーを追加したいがまだ 0 件: `ユーザー` 画面上部の `新規登録`
- 自社ユーザーを追加・無効化したい: `ユーザー`
- `ユーザー種別` や `会社` を変えたいように見えるが固定表示になっている: current role の範囲外なので internal admin へ引き継ぐ
- 案件所属や文書権限を見直したい: internal admin へ引き継ぐ
- `/admin` から入りたい: current `main` では `会社` 一覧へ redirect されるので、そこを入口に使う

## 補足

- `company_master_admin` 専用の dashboard はなく、`/admin` は許可済み画面への入口として扱う
- current behavior を変える判断は docs ではなく runtime 側の issue / PR で扱う

## 関連画面・根拠

- `docs/specs/基本モデルと権限.md`
- `app/controllers/admin/base_controller.rb`
- `app/controllers/admin/dashboard_controller.rb`
- `app/views/admin/_nav.html.slim`
- `app/views/admin/users/index.html.slim`
- `app/views/admin/users/_form.html.slim`
- `spec/requests/admin_management_spec.rb`