# 文書利用状況 q 検索運用メモ

このメモは `docs/文書利用状況運用runbook.md` の補足として、`admin/document_usage_reports` に追加した文書名 / slug 検索 `q` の current behavior を固定する。

## 対象

- `q` は、案件選択後に作られた文書利用状況の行を対象にする。
- 検索対象は `文書名` と `slug` の部分一致に限る。
- 大文字小文字は区別しない。
- `project_id` 未選択時は案件横断検索にはならず、従来どおり案件選択待ちの画面に留まる。

## 既存 filter との関係

`q` は集計後の行 filter として扱う。集計定義、AccessLog / ReadConfirmation の算出方法、KPI は変えない。

併用時の読み方:

- `usage_filter`、`from`、`to`、`sort_order` は従来どおり適用する。
- その結果に対して、`q` が `文書名` または `slug` に一致する行だけを残す。
- `q` は `利用状況` filter と OR ではなく AND 条件として読む。
- table preferences は表示列設定であり、検索条件や CSV の列定義にはしない。

## CSV

`CSV出力` は画面と同じ `q` 適用後の `@report_hash[:documents]` を出力する。

- CSV の列名と列順は従来どおり。
- CSV 専用の集計や案件横断 export は追加しない。
- table preferences で画面上の列を隠していても、CSV の列は固定のまま。

## empty state

`q` によって 0 件になった場合は、画面上で現在の検索語を表示する。

確認時は次を分けて読む。

- 案件未選択: まだ集計していない。
- 案件選択済みで 0 件: `利用状況` / 期間 / `q` の組み合わせで行が残っていない。

## 非対象

- full-text search / trigram index / DB index 追加
- 文書利用状況の集計定義変更
- CSV の列追加・列順変更
- 監査ログや既読確認内訳の検索変更
- 文書利用状況 dashboard の redesign
