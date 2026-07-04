# 文書マスタ maintenance mode 境界

このメモは #4512 の first slice として、`READ_ONLY_MAINTENANCE` 中に文書マスタで止める変更系操作と、止めずに read-only 確認として残す導線を整理する。

## 停止する操作

`READ_ONLY_MAINTENANCE` が有効な間、管理側の文書マスタ変更は開始しない。

- `Admin::DocumentsController#create`
  - 新しい `Document` を保存しない
- `Admin::DocumentsController#update`
  - title、slug、category、document kind、visibility policy、保管期限、廃棄候補を更新しない
- `Admin::DocumentsController#archive`
  - `archive!` を呼ばず、archived state、archived actor、retention / discard metadata を変更しない
- `Admin::DocumentsController#restore`
  - `restore!` を呼ばず、archived state を戻さない
- `Admin::DocumentsController#destroy`
  - `Document` を削除しない

停止時は `admin/documents` へ戻し、メンテナンス中のため登録・編集・アーカイブ・復元・削除を停止していることを alert で表示する。

## read-only として残す導線

maintenance mode 中も、次は確認用の read-only 導線として残す。

- 文書マスタ一覧
- 検索 / filter / pagination
- 文書マスタ編集画面での現在値確認
- 案件 remote search / selected project restore
- lifecycle handoff JSON
- 公開側文書への戻り導線
- 最新版 / HTML preview 状態、古い版候補、保管期限、廃棄候補の一覧確認

これらは文書の保存、archive / restore、削除を行わない確認導線として扱う。

## 非目標

この slice では次を変更しない。

- 文書 lifecycle / retention policy の最終判断
- `DocumentVersion` / `DocumentFile` の状態変更
- 文書公開 contract や権限 model
- bulk archive / bulk restore / bulk delete
- 文書一括編集 dry-run flow
- lifecycle handoff の大規模 redesign
- production infra / LB / CDN 側 maintenance page

## 確認観点

request spec では次を確認する。

- maintenance mode ON で create が `Document` を増やさない
- maintenance mode ON で update が文書メタデータを変更しない
- maintenance mode ON で archive / restore が archived state を変更しない
- maintenance mode ON で destroy が `Document` を削除しない
- maintenance mode ON でも一覧、編集画面、project search、lifecycle handoff が読める
- maintenance mode OFF の既存 archive / restore flow を壊さない
