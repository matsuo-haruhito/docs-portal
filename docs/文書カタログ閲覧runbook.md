# 文書カタログ閲覧runbook

この runbook は、current `main` の `文書カタログ` 画面を、案件内の文書グルーピング入口として確認するときの読み方をまとめる。

新しい管理 UI、公開ポリシー、保存済み filter はここでは定義しない。current route、controller、model、view を前提に、「どのカタログが見えるか」「一覧 filter をどう読むか」「カタログ内の文書がなぜ欠けて見えることがあるか」「文書セット・文書ショートカット・文書一覧とどう使い分けるか」を整理する。

## 先に見るもの

1. 案件内の文書を検索・ZIP 出力したいときは [文書一覧の検索・実用フィルタ・ZIP出力runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
2. 目的別の配布単位や固定版を管理したいときは [文書セット運用runbook](./文書セット運用runbook.md)
3. 個人導線としてよく見る文書を残したいときは [文書ショートカット運用runbook](./文書ショートカット運用runbook.md)
4. 案件所属や文書権限を見直したいときは [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md)

## 画面の役割

公開側の文書カタログは、案件配下の文書を「用途や対象者ごとの入口」としてまとめて見せるための閲覧画面である。

current route:

- 一覧: `projects/:project_code/document_catalogs`
- 詳細: `projects/:project_code/document_catalogs/:public_id`

current 実装の前提:

- controller は `project_code` で Project を取得し、先に `require_project_access!` を通す
- 一覧では、その案件の `document_catalogs.ordered` から current user が `viewable_by?` で見える catalog だけを表示する
- 一覧 filter は、見える catalog の中から `名称・説明`、`対象`、`公開範囲` で絞り込む
- 詳細では、catalog 自体が見えない場合は forbidden になる
- 詳細の item は `visible_items_for(current_user)` を通り、catalog が見えても文書ごとの閲覧権限がない item は表示されない
- 左側には既存の文書 tree が出るが、catalog の表示可否や item visibility は tree の展開状態とは別に判定される

## 一覧で見るポイント

一覧は、対象・公開範囲・現在の利用者に見える文書数で catalog を確認する画面として読む。

一覧には次の列が並ぶ。

- `名称`: 文書カタログ名。description がある場合は、名称の下に短い preview が表示される
- `対象`: `audience_type` の current 値
- `公開範囲`: `visibility_policy` の current 値
- `表示可能件数`: current user に見える item 数。header は `現在の利用者に見える文書`、row 補助は `現在の利用者に表示` として読める
- `詳細`: カタログ詳細への入口

`表示可能件数` は catalog に登録された総 item 数ではなく、current user がその時点で表示できる item 数として読む。想定より少ない場合は、catalog の設定だけでなく、文書ごとの `Document#viewable_by?`、案件所属、文書権限、文書の公開状態を確認する。

名称列の description preview は、catalog の用途や配布対象を一覧上で見分ける補助である。文書本文、文書 item、添付ファイルの検索結果ではない。

利用可能なカタログが 0 件の場合、一覧は `利用可能な文書カタログはありません。` を表示し、`案件トップへ戻る` で案件詳細へ戻る。

## 一覧 filter の読み方

一覧上部の filter は、catalog visibility を広げるものではない。先に current user が見える catalog だけに絞られ、その後で次の条件を適用する。

- `名称・説明`: catalog の `name` と `description` を部分一致で探す。入力は前後空白を除き、最大 100 文字までが検索条件・active filter label・現在条件URLに反映される。文書本文、item の文書名、添付ファイル名は検索対象ではない
- `対象`: `audience_type` の current enum で絞り込む。`customer` / `operations` などの分類であり、単独で閲覧許可を付与しない
- `公開範囲`: `visibility_policy` の current enum で絞り込む。外部ユーザーが `internal_only` を指定しても、見えない catalog が表示されるわけではない
- `絞り込み解除`: `q`、`audience_type`、`visibility_policy` を外して、current user に見える catalog 一覧へ戻す

`名称・説明` field 直下の helper copy は、検索対象がカタログ名・説明に限られることと、100 文字まで入力できることを確認する cue として読む。過長入力は controller 側でも 100 文字に丸められ、catalog item、文書本文、添付ファイル検索へ広げる指定にはならない。

条件を入れて 0 件になった場合は `条件に一致する文書カタログはありません。` と表示される。これは「この案件に catalog が存在しない」ではなく、「見える catalog の中に、いまの filter 条件に合うものがない」と読む。

`audience_type` や `visibility_policy` に current enum 以外の値が渡った場合、controller はその filter を採用しない。運用上は、不正な値でエラーになるものではなく、該当 filter を外した状態に近い一覧へ戻ると読む。

## `対象` と `公開範囲` の読み方

`audience_type` は catalog の想定読者や用途を示す分類であり、単独で閲覧許可を付与するものではない。

current enum:

- `customer`
- `internal`
- `developer`
- `delivery`
- `operations`
- `other`

`visibility_policy` は catalog 自体を誰に見せるかの大枠である。

current enum:

- `internal_only`: internal user だけが見える
- `restricted_external`: internal user と、対象 Project を見られる external user が見える
- `public_with_login`: internal user と、対象 Project を見られる login user が見える

外部ユーザーは、catalog が `internal_only` なら見えない。`restricted_external` / `public_with_login` でも、対象 Project を見られない user には見えない。

## 詳細で見るポイント

詳細画面では次を確認する。

- 案件名
- `対象`
- `公開範囲`
- catalog description
- `表示可能: n 件 / 登録: m 件`
- item の `順序` / `文書` / `メモ` / `種別` / `公開範囲`

`表示可能` と `登録` がずれる場合は、catalog には item が登録されているが、current user に見えない文書が含まれている状態として読む。これは catalog の不具合とは限らない。

item の `文書` link は、同じ案件配下の文書詳細へ戻る。current 実装では catalog item は同じ Project の document だけを持てるため、catalog 詳細から別案件の document へ直接飛ばす用途ではない。

詳細に表示できる item が 0 件の場合、表示文言は登録済み item の有無で分かれる。

- `登録: 0 件` の場合は `このカタログにはまだ文書が登録されていません。` と表示される。catalog item がまだ登録されていない状態として読む。
- `登録: 1 件以上` かつ `表示可能: 0 件` の場合は `登録済みの文書はありますが、現在の利用者に表示できる文書はありません。` と表示される。catalog には item があるが、current user には文書ごとの閲覧権限や公開状態の都合で表示されない状態として読む。

後者の場合も catalog 自体は見えているため、次の順で確認する。

1. 登録済み item の document が current user に見えない状態か
2. Project membership または DocumentPermission が intended か
3. 対象文書の公開状態や visibility が intended か

## 文書セット・ショートカット・文書一覧との違い

- 文書カタログ
  - 案件内の文書を、用途・対象者・公開範囲の入口として並べる閲覧導線
  - catalog 自体の visibility と item 文書の visibility を二段階で読む
  - 一覧 filter は catalog を探すための一時的な絞り込みで、権限・公開範囲・item 構成を変更しない
- 文書セット
  - 管理側で配布単位や固定版を扱う単位
  - `固定版` と `最新版を使う` の運用は文書セット runbook を正本にする
- 文書ショートカット
  - current user の `お気に入り` / `後で読む` / `最近見た文書` などの個人導線
  - catalog の公開範囲や item visibility を変更しない
- 文書一覧
  - 案件内の文書を検索、実用 filter、ZIP 出力で探す導線
  - catalog は検索条件保存や ZIP 出力範囲の代替ではない

## 変更時の注意

- `audience_type` は分類であり、権限判定の代替ではない
- catalog が見えても、item 文書ごとの閲覧権限がなければ詳細には出ない
- `internal_only` catalog を外部ユーザー向けに表示する運用として読まない
- 一覧の `名称・説明`、`対象`、`公開範囲` filter は current user に見える catalog の中だけを絞り込む
- `条件に一致する文書カタログはありません。` と `利用可能な文書カタログはありません。` は別の状態として読む
- 管理 UI、公開範囲 policy、保存済み filter、sort 変更、item 一括編集はこの runbook に含めない
- 文書カタログから見えない文書を、tree や文書一覧で見えるべきとは自動判断しない。案件所属、文書権限、公開状態のどれが正かは既存仕様に戻して確認する

## 関連文書

- [文書一覧の検索・実用フィルタ・ZIP出力runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
- [文書セット運用runbook](./文書セット運用runbook.md)
- [文書ショートカット運用runbook](./文書ショートカット運用runbook.md)
- [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md)
- [基本モデルと権限](./specs/基本モデルと権限.md)
- [閲覧画面とUI](./specs/閲覧画面とUI.md)
- [README](../README.md)
- [docs/README](./README.md)