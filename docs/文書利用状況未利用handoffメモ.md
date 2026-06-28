# 文書利用状況 未利用 handoff メモ

このメモは、管理画面の `文書利用状況` で `利用状況=未利用` を選んだときに表示される `未利用文書 handoff` の read-only digest を、次の確認者へ渡すときの読み方をまとめる。

`文書利用状況運用runbook.md` の補助メモであり、新しい KPI、削除判断、archive 判断、retention policy、CSV 仕様、集計定義はここでは定義しない。

## いつ使うか

- 選択した案件で、現在期間内に閲覧・ダウンロード・既読確認がない文書を次の確認者へ渡したいとき
- `文書名 / slug`、期間、並び順、`利用状況=未利用` の現在条件を短い Markdown として残したいとき
- 未利用候補の代表行だけを共有し、詳細確認は文書詳細、監査ログ、既読確認内訳、既存 CSV へ戻したいとき

## digest に含まれるもの

`未利用文書 handoff` は `usage_filter=unused` のときだけ集計サマリ内に表示される read-only textarea である。

含まれる情報:

- 案件: `code / name`
- 期間: `指定なし`、開始日以降、終了日まで、または開始日から終了日まで
- 利用状況: `未利用`
- 並び順: 現在の sort order
- 検索: 現在の `文書名 / slug` 検索語、または `なし`
- 表示中の未利用文書数
- 案件全体の未利用文書数
- 代表文書: 表示中の先頭 5 件まで

代表文書には、文書名、slug、カテゴリ、種別、公開範囲、最終アクセスが含まれる。全件 export ではないため、6 件目以降や CSV と同じ棚卸しが必要な場合は既存の `CSV出力` を使う。

## 読み違えやすい境界

- `未利用` は現在期間内の閲覧・ダウンロード・既読確認がない候補であり、不要・削除・archive 確定ではない
- 期間指定ありの場合、期間外の利用実績は digest の未利用判定に含まれない
- digest は read-only の確認依頼用であり、bulk action、retention policy、CSV format、集計定義を変更しない
- table preferences で画面上の列を隠していても、digest の現在条件や未利用判定は変わらない
- 代表文書の `最終アクセス` は AccessLog 由来であり、既読確認だけの文書では空欄になりうる

## 確認の戻り先

- 個別の閲覧・ダウンロード履歴を追う: [監査ログ運用runbook](./監査ログ運用runbook.md)
- 既読確認の確認者や確認時刻を見る: [文書利用状況運用runbook](./文書利用状況運用runbook.md) の `既読確認内訳` 節
- 文書の公開状態や版状態を見直す: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)
- 権限や閲覧可能範囲を見直す: [基本モデルと権限](./specs/基本モデルと権限.md)

## 変更時の注意

`未利用文書 handoff` の文言や項目を変えるときは、`app/helpers/admin/document_usage_reports_helper.rb` の `document_usage_report_unused_handoff_digest` と `app/views/admin/document_usage_reports/index.html.slim` の表示条件を正本にする。

request spec は `spec/requests/admin_document_usage_report_unused_handoff_spec.rb` を確認し、docs だけで現在の実装を超える挙動を書かない。