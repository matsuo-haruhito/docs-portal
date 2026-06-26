# CSV条件metadata JSON 運用メモ

このメモは、監査ログの `CSV条件metadata JSON`、文書利用状況の `CSV条件をJSONで確認`、文書セット CSV の `GET /admin/document_sets.json` response を、CSV 本体とは別の companion metadata として読むための補助です。current code では PR #3079 で追加された監査ログ / 文書利用状況の `format: :json` response と、PR #3851 で追加された文書セット CSV metadata response が対象で、CSV header / row contract、表示設定、集計定義、export 対象の境界は変えません。

## 位置づけ

`CSV条件metadata JSON` / `CSV条件をJSONで確認` / `GET /admin/document_sets.json` は、CSV を開く前に「どの条件で出した CSV か」を短く確認するための JSON です。CSV 本体へ metadata row、pre-header、footer を足すものではありません。

- CSV 本体: 既存の固定列 / 行を出す成果物
- metadata JSON: 同じ条件、正規化済み filter、summary、無効日付や未対応 enum 値の除外などを確認する companion
- HTML 表示設定: 画面上の列の見え方だけを変える補助。CSV 列や metadata の条件は変えない

## 監査ログ

`admin/access_logs` では、`現在の条件でCSV export（最新200件）` の隣に `CSV条件metadata JSON` が出ます。

監査ログの metadata JSON は、現在の filter 条件に一致する最新 200 件 CSV の companion として読みます。page 移動中でも、CSV と metadata は表示中 page ではなく current filter の最新 200 件を対象にします。

主に確認する項目:

- `report_type`: `access_logs`
- `row_limit`: 監査ログ CSV の最新 200 件上限
- `export_scope`: `current_filter_latest_rows`
- `filters`: action type、target type、project / company / user、`q`、`document_q`、期間、AI context mode / scope などの正規化済み条件
- `ignored_filters`: 不正な `from` / `to` など、warning として除外された日付条件
- `summary`: 監査ログ、最新 200 件、現在の絞り込み条件、無効日付の除外を短くまとめた文字列

運用上の読み方:

- `page` は metadata link に含めません。2 ページ目を見ていても、CSV / metadata は current filter の最新 200 件を説明します。
- 無効日付が `ignored_filters` に出ている場合、CSV にもその日付条件は適用されていません。画面の warning と合わせて、条件を直すか、残った条件だけで意図どおりか確認します。
- `filters.project` / `filters.company` / `filters.user` は補助説明です。ID がある場合に code / name / email などを添えるだけで、権限や検索範囲は変えません。
- 表示設定で HTML の列を隠していても、CSV の固定列と metadata の条件は変わりません。

## 文書利用状況

`admin/document_usage_reports` では、案件を選択して集計が表示されたときに `CSV出力` の隣に `CSV条件をJSONで確認` が出ます。

文書利用状況の metadata JSON は、同じ案件、文書名 / slug 検索、利用状況、並び順、期間条件で出す CSV の companion として読みます。案件未選択や invalid `project_id` の場合は、CSV と同じく全件 export へ広げず、案件選択を促す挙動に戻します。

主に確認する項目:

- `report_type`: `document_usage_report`
- `export_scope`: `current_project_usage_report`
- `filters.project`: 案件 code / name / public_id
- `filters.q`: 正規化済みの文書名 / slug 検索語
- `filters.usage_filter` / `usage_filter_label`: 利用状況 filter と表示ラベル
- `filters.sort_order` / `sort_order_label`: 並び順と表示ラベル
- `filters.from` / `filters.to` / `period_label`: 期間条件と画面上の期間ラベル
- `ignored_filters`: 不正な日付条件が除外された場合の条件名
- `row_count`: 現在の集計条件に残った文書行数
- `summary`: 案件、期間、利用状況、並び順、検索語、行数を短くまとめた文字列

運用上の読み方:

- `row_count` は CSV に出る文書行数の確認用です。新しい KPI や別集計ではありません。
- invalid `project_id` や案件未選択時に metadata JSON だけで案件横断 export ができる、とは読まないでください。
- `q`、利用状況、並び順、期間は CSV と同じ条件です。HTML の `文書利用一覧の表示設定` で隠した列は CSV / metadata の条件や列を変えません。
- 無効日付が `ignored_filters` に出ている場合、その期間条件は集計・CSV・metadata のいずれにも適用されていません。

## 文書セット

`admin/document_sets` では、同じ一覧 endpoint の JSON response として `GET /admin/document_sets.json` で文書セット CSV の companion metadata を確認できます。画面上の `CSV出力` link が出す CSV 本体とは別に、同じ `q` / `set_type` / `visibility_policy` 条件を JSON で見返すための read-only response です。

文書セットの metadata JSON は、文書セット CSV と同じ filter 条件で対象集合を数えます。表示中 page だけではなく current filter に一致する全件を対象にし、`文書セット一覧の表示設定` の列表示・幅とは連動しません。

主に確認する項目:

- `report_type`: `document_sets`
- `export_scope`: `current_filters`
- `description`: CSV 本体の行データではないことの説明
- `filters.q`: 前後空白を除いた検索語
- `filters.set_type` / `filters.visibility_policy`: valid な enum filter の value と表示 label
- `ignored_filters`: unsupported な `set_type` / `visibility_policy` が指定された場合の値
- `row_count`: CSV と同じ current filter 条件に一致する文書セット数
- `csv_headers`: `案件コード`、`案件名`、`文書セット名`、`種別`、`公開範囲`、`文書数`、`public_id`
- `summary.matching_document_sets`: `row_count` と同じ対象件数
- `summary.filter_labels`: 画面の `適用中:` badge と同じ読み方の filter label
- `summary.csv_filename`: CSV 本体の filename
- `summary.csv_columns_fixed`: 表示設定と独立した固定列であること

運用上の読み方:

- `GET /admin/document_sets.json?q=...&set_type=...&visibility_policy=...` は条件確認用 metadata だけを返し、文書セット行データ本体や `public_id` の一覧を返す API ではありません。
- unsupported な `set_type` / `visibility_policy` は CSV と同じく絞り込み条件としては使われず、`ignored_filters` で確認します。
- `row_count` は current filter に一致する文書セット集合の件数です。表示中 page の行数や、`文書セット一覧の表示設定` で見えている列数ではありません。
- `csv_headers` は CSV の固定列を確認するための補助です。表示設定で table の列を隠したり幅を変えたりしても、CSV header、CSV row、metadata 条件は変わりません。

## 変更時の注意

- CSV の fixed header / row を変えたい場合は、この metadata JSON メモではなく CSV contract と request spec を先に確認します。
- metadata JSON は調査入口であり、scheduled report、background export、全件 export、retention policy、表示設定連動を current support として意味しません。
- 監査ログ、文書利用状況、文書セットの JSON 形は似ていますが、監査ログは「current filter の最新 200 件」、文書利用状況は「選択案件の current usage report」、文書セットは「current filter に一致する文書セット CSV」です。対象範囲を混同しないでください。
- 生成ファイル実行履歴の `一括再実行の対象条件` cue は、CSV metadata JSON ではなく bulk retry の押下前確認 cue です。生成ファイル runbook 側の説明を正本にします。

## 関連

- [監査ログ運用runbook](./監査ログ運用runbook.md)
- [文書利用状況運用runbook](./文書利用状況運用runbook.md)
- [文書セット運用runbook](./文書セット運用runbook.md)
- [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md)
