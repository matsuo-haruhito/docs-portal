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

current `main` では、`/admin` へ入ると `会社・ユーザー管理` の landing が表示される。

ローカル開発 / demo でこの flow を確認する場合は、README の [サンプルログイン情報](../README.md#サンプルログイン情報) を正本にし、`rails db:seed` 後の代表 account `company-admin-a@client-a.example.com` / `password123!` を使う。この credential は `/admin` landing、`会社` / `ユーザー` 管理、通常閲覧への戻り方を確認するための seed credential であり、共有環境や本番 credential、認証 policy の例として扱わない。

landing は role-aware な入口であり、次だけを表示する。

- 使える管理画面: `会社を管理` / `ユーザーを管理` の primary action から進む `会社` と `ユーザー` の 2 画面
- 左 nav: `会社・ユーザー管理` の領域見出しと、許可済みの `会社` / `ユーザー` link だけを表示する。現在開いている `会社` / `ユーザー` は太字と `aria-current="page"` で示される
- internal admin へ戻す範囲: `案件・案件所属`、`文書・文書権限`、`運用確認`、`管理者判断` の確認リスト
- ユーザーが 0 件のときは `ユーザー` 画面上部の `新規登録` から開始できること
- internal admin へ依頼するときに添える確認項目と、ticket や chat に貼り付けるための `依頼テンプレート`
- landing 下部の `通常の案件一覧へ戻る` は、admin surface ではなく通常閲覧側の案件一覧へ戻る導線として読む

landing から forbidden な admin surface への link は出さない。日常運用では次の flow を入口として使う。

- `/admin` から入って `会社・ユーザー管理` landing で範囲を確認する
- 左 nav の `会社・ユーザー管理` 見出しと `会社` / `ユーザー` の current cue で、いま company master admin 専用の許可済み領域にいることを確認する
- `会社を管理` または `ユーザーを管理` から、許可済みの `会社` / `ユーザー` 画面へ移動する
- それ以外の admin surface が必要になったら、確認リストの分類に沿って internal admin へ引き継ぐ
- internal admin へ引き継ぐときは、`依頼テンプレートをコピー` を使うか、JavaScript / clipboard が使えない場合は template text を手動選択して貼り付ける
- admin での確認を終えて通常の案件一覧へ戻るときは、landing 下部の `通常の案件一覧へ戻る` を使う

## internal admin へ引き継ぐときの確認項目

依頼先名、メールアドレス、ticket URL は hard-code しない。組織ごとの連絡手段に従い、次の情報を添えて internal admin へ渡す。

- 自社会社名
- 対象ユーザーの名前とメールアドレス
- 必要な案件所属、文書権限、アクセス申請などの目的
- 依頼内容が `案件・案件所属`、`文書・文書権限`、`運用確認`、`管理者判断` のどれに近いか
- ユーザー種別を `internal` に変える相談か、他社会社・他社ユーザーの調整か
- 期限や背景がある場合は、その理由と希望時期

依頼テンプレートの copy button は、上の情報を ticket や chat へ移しやすくするための補助である。コピーに成功すると `依頼テンプレートをコピーしました。`、clipboard が使えない場合や失敗した場合は手動選択を促す短い状態表示が出る。

current `main` の依頼テンプレートは、画面上で分類と入力欄を調整してから textarea の copy target に反映する。

- `案件・案件所属` / `文書・文書権限` / `運用確認` / `管理者判断` の 4 分類から選ぶと、`依頼内容`、`確認項目`、`user type 変更相談` の初期値が切り替わる
- 選んだ分類の読み方は landing 上にも表示され、radio の選択に合わせて入力欄の初期値が切り替わり、下のコピー対象 textarea に反映される
- `対象ユーザー`、`依頼内容`、`確認項目`、`user type 変更相談`、`期限・背景` は画面上で編集でき、入力内容が template text に反映される
- default は `案件・案件所属` で、`管理者判断` を選ぶと user type 変更相談が `あり` になる
- user type 変更相談が `あり` の分類は、会社管理者だけで権限や所属会社を判断せず、internal admin / human 判断待ちとして引き継ぐ
- copy 対象は画面上の textarea であり、選択中の分類と入力欄から生成される。clipboard が使えない場合も同じ template text を手動選択して貼り付けられる

この checklist と copy button は依頼内容を整理するためのものであり、`company_master_admin` の権限、文書閲覧範囲、案件所属、文書権限を広げるものではない。依頼先 URL、ticket system、chat、mail 連携、forbidden admin surface への direct link も current support として固定しない。

## 1. 会社画面でできること

`/admin/companies` では、自社の会社マスタだけを一覧・更新できる。

current `main` で確認できること:

- 一覧には自社の会社だけが出る
- `会社を探す` で、キーワードと状態 filter を使って表示中 scope の会社を絞り込める
- キーワードは `domain` と `name` の断片に一致する会社を探す。画面上の placeholder / helper copy もドメイン・会社名に揃っており、入力欄は最大100文字。表示名は一覧列として確認する
- 状態 filter は `すべて` / `有効` / `無効` を選べる
- 検索や状態 filter を使っても、`company_master_admin` は自社会社 scope を越えない
- filter 適用中は form の下に `適用中: ...` と `検索結果: N件` が出る。キーワードと状態を両方使う場合は `キーワード「...」 / 状態: ...` のように並ぶ
- `検索結果: N件` は現在のキーワード・状態 filter に一致する会社の総件数を表す。列の表示設定を変えても、この件数や検索条件、権限 scope は変わらない
- 一覧は bounded pagination で表示され、通常は 1 ページ 25 件ずつ確認する。URL の `per_page` は最大 100 件までに丸められる
- 一覧の上に出る `表示中: X-Y件 / N件` は、現在ページで表示している範囲と filter 後総件数を分けて読む
- 複数ページある場合は `前へ` / `次へ` と `現在ページ / 総ページ` が出る。page 移動時も `q` / `active` / `per_page` は維持される
- 一覧の `編集` link（internal admin では `削除` link も）は、現在の検索条件・page を `return_to` として持つ。更新 / 削除後は安全な内部 path だけへ戻り、外部 URL や unsafe path は会社一覧へ fallback する
- 一覧には `会社一覧の表示設定` があり、列の表示状態を調整できる
- 表示設定の列は `ドメイン`、`会社名（表示用）`、`表示名`、`状態`、`操作` に分かれている
- 画面上部の form 見出しは `自社会社情報の更新` になり、会社を新規登録できる導線としては表示されない
- 自社の `domain` `name` `active` は更新できる
- 一覧の action は `編集` のみで、`company_master_admin` には会社の `削除` link は出ない
- 他社の会社更新は `not_found` になる
- 会社の新規作成は `forbidden` になる
- 表示できる会社が 0 件のときは空 table ではなく、internal admin へ確認する empty state が出る
- 登録済み会社はあるが filter 条件に一致しないときは、`検索条件に一致する会社はありません。` と表示され、条件変更または `条件をクリア` を促す。filter 適用中は empty state の中にも `条件をクリア` link が出る

使いどころ:

- 自社会社名やドメイン表記の修正
- 自社会社の active 状態の見直し
- 会社一覧で業務上見る列を表示設定で調整する
- 対象会社をドメイン・会社名の断片や有効/無効状態で探す。キーワード入力欄は最大100文字で、表示名は検索対象ではなく一覧列として確認する
- `適用中` と `検索結果` を見て、現在の絞り込み条件と filter 後総件数を確認する
- `表示中` と `前へ` / `次へ` を見て、現在ページの範囲と次に確認するページを把握する
- filter や page を使った状態で会社を編集すると、保存後は安全な `return_to` によって元の一覧条件へ戻る

internal admin へ戻すもの:

- 他社会社の修正
- 会社の新規登録や削除方針の判断
- 案件や文書の管理と一緒に行う調整

## 2. ユーザー画面でできること

`/admin/users` では、自社に所属するユーザーだけを一覧・更新・追加できる。

current `main` で確認できること:

- 一覧には自社ユーザーだけが出る
- `ユーザーを探す` で、キーワードと状態 filter を使って表示中 scope のユーザーを絞り込める
- キーワードは `name` と `email_address` の断片に一致するユーザーを探す。画面上の placeholder / helper copy もユーザー名・メールアドレスに揃っており、入力欄は最大100文字。表示名は一覧列として確認する
- 状態 filter は `すべて` / `有効` / `無効` を選べる
- 検索や状態 filter を使っても、`company_master_admin` は自社ユーザー scope を越えない
- filter 適用中は form の下に `適用中: ...` と `検索結果: N件` が出る。キーワードと状態を両方使う場合は `キーワード「...」 / 状態: ...` のように並ぶ
- `検索結果: N件` は現在のキーワード・状態 filter に一致するユーザーの総件数を表す。列の表示設定を変えても、この件数や検索条件、権限 scope は変わらない
- 一覧は bounded pagination で表示され、通常は 1 ページ 25 件ずつ確認する。URL の `per_page` は最大 100 件までに丸められる
- 一覧の上に出る `表示中: X-Y件 / N件` は、現在ページで表示している範囲と filter 後総件数を分けて読む
- 複数ページある場合は `前へ` / `次へ` と `現在ページ / 総ページ` が出る。page 移動時も `q` / `active` / `per_page` は維持される
- 一覧の `編集` / `削除` link は、現在の検索条件・page を `return_to` として持つ。更新 / 削除後は安全な内部 path だけへ戻り、外部 URL や unsafe path はユーザー一覧へ fallback する
- 表示中の範囲にユーザーが 0 件のときは、空 table ではなく `ユーザー一覧` の empty state が出る
- 登録済みユーザーはいるが filter 条件に一致しないときは、`検索条件に一致するユーザーはありません。` と表示され、条件変更または `条件をクリア` を促す。filter 適用中は empty state の中にも `条件をクリア` link が出る
- 0 件時は上の `新規登録` card から、メールアドレスと必要な項目を入れて最初の 1 件を作る
- `/admin` landing の `ユーザーを管理` からも `ユーザー` へ直接移動できる
- 他社ユーザーの edit は `not_found` になる
- 自社ユーザーの `name` や `active` は更新できる
- `company_master_admin` が見る form では、`ユーザー種別` は `external` 固定、`会社` は自社固定の read-only 表示になる
- internal admin が見る form では、`会社` は remote combobox になり、会社名 / domain の断片で最大 20 件の候補を検索する
- internal admin の remote combobox は検索語を最大 100 文字まで使い、保存済み company や validation error 後の selected company は selected endpoint で復元する
- internal admin は会社選択をクリアすると未所属ユーザーとして保存できる
- `company_master_admin` が見る form では remote search は表示されず、会社は自社固定表示のままになる
- form で `internal` や他社 `company_id` を送っても、保存時には `external` / 自社所属へ矯正される
- 新規作成も自社所属の `external` user として保存される

使いどころ:

- 自社ユーザーがまだいないときの最初の登録
- 自社ユーザーの有効化・無効化
- 自社ユーザー名やメールアドレスの保守
- 自社メンバーの追加
- internal admin が全社ユーザーを登録・編集するときに、会社名・ドメインの断片で所属会社を探し、候補上限外の保存済み会社も selected company として復元する
- 対象ユーザーを名前・メールアドレスの断片や有効/無効状態で探す。キーワード入力欄は最大100文字で、表示名は検索対象ではなく一覧列として確認する
- `適用中` と `検索結果` を見て、現在の絞り込み条件と filter 後総件数を確認する
- `表示中` と `前へ` / `次へ` を見て、現在ページの範囲と次に確認するページを把握する
- filter や page を使った状態でユーザーを編集・無効化すると、保存後は安全な `return_to` によって元の一覧条件へ戻る

internal admin へ戻すもの:

- user type を `internal` へ変える相談
- 他社所属ユーザーの調整
- 案件所属や文書権限まで含む広いアクセス設計

## 3. ユーザーフォームの会社選択の見え方

`company_master_admin` が `ユーザー` の新規登録や編集を開くと、current `main` では保存結果に沿った fixed 表示を先に見せる。

company_master_admin の見分け方:

- `ユーザー種別` は選択肢ではなく、`external` 固定の表示として見える
- `会社` も選択肢ではなく、自社名の固定表示として見える
- `name` `email_address` `active` `password` `password_confirmation` は通常どおり入力・更新する
- 固定会社欄の近くに「この会社で固定され、会社欄は変更できません。ユーザー種別も自動で固定されます。」という補足 copy が表示される

internal admin が同じ form を開くと、会社欄は `会社名・ドメインで検索（未所属可）` の remote combobox として見える。

internal admin の見分け方:

- 会社名 / domain の断片を 1 文字以上入力すると候補が最大 20 件まで出る
- 候補 label は display name に domain がある場合 `表示名 / domain` の形で出る
- 編集時や validation error 後は、候補上限外でも保存済み company が selected endpoint で復元される
- 選択をクリアすると未所属として保存できる

意味合い:

- 画面上で `internal` や他社所属を選べないように見せつつ、server-side の保存契約とも矛盾しないようにしている
- role を広げたのではなく、もともとの保存矯正ルールを UI でも読み取りやすくした current state と考える
- internal admin の remote search は会社選択の payload と操作性を改善するためのもので、company_master_admin の自社固定 scope や role / policy の境界は変更しない

## 4. 入れない管理画面

current request spec で `company_master_admin` が forbidden として固定されている主な画面は次のとおり。

- `案件`
- `案件所属`
- `文書`
- `文書権限`
- `監査ログ`
- `利用状況`

意味合い:

- `company_master_admin` は company / user master の最小管理 role であり、案件運用や公開制御の role ではない
- 文書閲覧や添付ダウンロードは、管理画面ではなく通常の project / document 側の権限で判断される
- `/admin` landing でもこれらの画面へ link せず、internal admin へ戻す範囲としてだけ表示する

## 5. 文書閲覧境界の見方

`company_master_admin` の閲覧権限は `external` と同じルールで決まる。

- `ProjectMembership` がない案件は見えない
- `DocumentPermission` が必要な文書は、許可がない限り見えない
- `internal_only` 文書は company master でも閲覧できない
- 添付ファイル download は `download` 権限が必要

つまり、`会社` と `ユーザー` を管理できても、文書閲覧の範囲は internal admin より広がらない。

## 日常運用の見分け方

- `/admin` から入りたい: `会社・ユーザー管理` landing で範囲を確認し、左 nav の `会社・ユーザー管理` 見出しと `会社` / `ユーザー` の current cue で company master admin 専用領域にいることを確認してから、`会社を管理` または `ユーザーを管理` へ進む
- 自社会社情報を直したい: `会社を管理`
- 会社一覧の列を調整したい: `会社一覧の表示設定` で `ドメイン`、`会社名（表示用）`、`表示名`、`状態`、`操作` の表示状態を見直す
- 自社会社を探したい: `会社を探す` でドメイン・会社名の断片や有効/無効状態を絞り込む。キーワード入力欄は最大100文字で、表示名は検索対象ではなく一覧列として確認する
- 会社画面で `適用中: ...` と `検索結果: N件` が出ている: keyword または状態 filter がかかっている。検索結果件数は現在の filter 後総件数であり、列の表示設定では変わらない
- 会社画面で `表示中: X-Y件 / N件` が出ている: 現在ページに表示されている範囲と filter 後総件数を分けて読む。複数ページある場合は `前へ` / `次へ` で同じ条件のまま移動する
- 会社一覧から編集する: filter や page を使っている場合、`編集` は現在の一覧条件を戻り先として持つ。保存後に戻り先が外部 URL になることはない
- `検索条件に一致する会社はありません。` が出る: 自社会社 scope 内に登録済み会社はあるが、現在の keyword / 状態 filter に一致していない。条件変更か `条件をクリア` を使う
- 会社画面で `新規登録` や `削除` を探している: current role の範囲外なので internal admin へ引き継ぐ
- 自社ユーザーを追加したいがまだ 0 件: `ユーザーを管理` から入り、`ユーザー` 画面上部の `新規登録`
- 自社ユーザーを追加・無効化したい: `ユーザーを管理`
- internal admin としてユーザーの会社を選ぶ: ユーザー form の `会社` で会社名・ドメインを検索し、未所属にする場合は選択をクリアする。company_master_admin ではこの欄は固定表示のまま
- 自社ユーザーを探したい: `ユーザーを探す` で名前・メールアドレスの断片や有効/無効状態を絞り込む。キーワード入力欄は最大100文字で、表示名は検索対象ではなく一覧列として確認する
- ユーザー画面で `適用中: ...` と `検索結果: N件` が出ている: keyword または状態 filter がかかっている。検索結果件数は現在の filter 後総件数であり、列の表示設定では変わらない
- ユーザー画面で `表示中: X-Y件 / N件` が出ている: 現在ページに表示されている範囲と filter 後総件数を分けて読む。複数ページある場合は `前へ` / `次へ` で同じ条件のまま移動する
- ユーザー一覧から編集・無効化する: filter や page を使っている場合、`編集` / `削除` は現在の一覧条件を戻り先として持つ。保存後に戻り先が外部 URL になることはない
- `検索条件に一致するユーザーはありません。` が出る: 自社 scope 内に登録済みユーザーはあるが、現在の keyword / 状態 filter に一致していない。条件変更か `条件をクリア` を使う
- `ユーザー種別` や `会社` を変えたいように見えるが固定表示になっている: current role の範囲外なので internal admin へ引き継ぐ
- 案件所属や文書権限を見直したい: internal admin へ引き継ぐ
- internal admin へ依頼する: `案件・案件所属` / `文書・文書権限` / `運用確認` / `管理者判断` から近い分類を選び、対象ユーザー、依頼内容、確認項目、user type 変更相談、期限・背景を調整してから `依頼テンプレートをコピー` を使う。copy が使えない場合は、textarea の template text を手動選択して貼り付ける
- admin での確認を終えて通常閲覧へ戻りたい: landing 下部の `通常の案件一覧へ戻る` は、admin surface ではなく通常の案件一覧へ戻る link として使う

## 補足

- `company_master_admin` 専用の広い dashboard はなく、`/admin` は許可済み画面への role-aware landing として扱う
- internal admin 向けの診断 card、model browser、広い管理リンクは `company_master_admin` には表示しない
- current behavior を変える判断は docs ではなく runtime 側の issue / PR で扱う

## 関連画面・根拠

- `docs/specs/基本モデルと権限.md`
- `app/controllers/admin/base_controller.rb`
- `app/controllers/admin/dashboard_controller.rb`
- `app/controllers/admin/companies_controller.rb`
- `app/controllers/admin/users_controller.rb`
- `app/helpers/admin/companies_helper.rb`
- `app/helpers/admin/users_helper.rb`
- `app/views/admin/dashboard/company_master_admin.html.slim`
- `app/views/admin/dashboard/index.html.slim`
- `app/views/admin/_nav.html.slim`
- `app/views/admin/companies/index.html.slim`
- `app/views/admin/users/index.html.slim`
- `app/views/admin/users/_form.html.slim`
- `app/frontend/controllers/company_master_admin_handoff_controller.js`
- `spec/frontend/company_master_admin_handoff_source_spec.rb`
- `spec/frontend/admin_companies_source_spec.rb`
- `spec/requests/admin_company_master_admin_boundary_spec.rb`
- `spec/requests/admin_company_master_filters_spec.rb`
- `spec/requests/admin_company_master_visibility_spec.rb`
- `spec/requests/admin_management_spec.rb`
- `spec/requests/admin_user_company_picker_spec.rb`
- `spec/requests/admin_users_filters_spec.rb`
- `spec/requests/company_master_admin_landing_spec.rb`
