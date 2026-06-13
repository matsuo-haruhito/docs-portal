# company_master_admin 依頼テンプレート UI visual check

## 目的

company_master_admin landing の internal admin 依頼テンプレート UI が、現行の 4 分類切替と編集欄つき copy target のまま、desktop / narrow viewport で読めることを確認するための QA handoff checklist です。

この note は #2947 の browser smoke checklist です。実レンダリング結果の証跡は request spec で固定し、この note 単体を visual evidence の代替にはしません。権限、保存 contract、依頼先連携、forbidden admin surface への direct link は変更しません。

## 対象 surface

- Route: `/admin`
- Role: company_master_admin
- Section heading: `internal admin へ依頼するときの確認項目`
- Controller: `company-master-admin-handoff`

## Browser smoke matrix

### Desktop viewport

- `使える管理画面` の会社 / ユーザー CTA と、handoff section が縦に追えること。
- `依頼分類` の 4 分類が同じ group として読めること。
- `対象ユーザー`、`user type 変更相談`、`依頼内容`、`確認項目`、`期限・背景` の編集欄が handoff section 内で見つかること。
- `依頼テンプレートをコピー` button、copy status、copy target textarea が同じ操作 block として読めること。
- textarea に `【会社】`、`【依頼者】`、`【分類】`、`【対象ユーザー】`、`【依頼内容】`、`【確認項目】`、`【user type 変更相談】`、`【期限・背景】` が並ぶこと。

### Narrow viewport

- 4 分類の radio label が重ならず、分類名と補足文が同じ label 内で読めること。
- 5 つの編集欄が縦方向に追え、label と input / textarea の対応が崩れないこと。
- copy button、copy status、manual selection fallback 用 textarea が画面幅からはみ出さないこと。
- `連絡先や forbidden admin surface への direct link はここでは固定しません。` と権限非拡張の補足が読めること。

## Interaction checks

- `文書・文書権限`、`運用確認`、`管理者判断` に切り替えると、copy target の `【分類】`、`【依頼内容】`、`【確認項目】`、`【user type 変更相談】` が選択分類の内容に更新されること。
- 編集欄を変更すると、copy target textarea に入力内容が反映されること。
- clipboard success では `依頼テンプレートをコピーしました。` が role=status に表示されること。
- clipboard unsupported / failure では `テンプレートを選択してコピーしてください。` を含む手動選択 fallback が表示されること。

## Non-goals

- company_master_admin landing の redesign
- internal admin への自動送信
- ticket / chat / mail 連携
- forbidden admin surface への direct link 追加
- company_master_admin の権限拡張
- 会社 / ユーザー管理、案件所属、文書権限の保存 contract 変更
