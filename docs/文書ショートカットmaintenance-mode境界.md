# 文書ショートカット maintenance mode 境界

このメモは、`READ_ONLY_MAINTENANCE` 中の文書ショートカット操作を、read-only 確認と状態変更に分けて読むための運用境界です。

## current support

`READ_ONLY_MAINTENANCE` が有効なとき、文書ショートカットの状態変更は停止します。

停止する操作:

- `DocumentBookmarksController#create`
  - `お気に入りに追加`
  - `後で読むに追加`
- `DocumentBookmarksController#move_to_favorite`
  - `後で読む` から `お気に入りへ移す`
- `DocumentBookmarksController#destroy`
  - `お気に入り` / `後で読む` の `解除`

停止時は `DocumentBookmark` の作成、favorite 作成、read_later 削除、bookmark 削除を開始しません。利用者には、メンテナンス中のため追加・移動・解除を停止していることを alert で表示します。

## read-only に残すもの

maintenance mode 中も、次の確認は継続します。

- `GET /document_bookmarks`
- `お気に入り` / `後で読む` の一覧表示
- 保存済みショートカットの案件 filter / 検索語 filter
- `最近見た文書` の表示と `recent_q` 検索
- section ごとの pagination
- 文書詳細へのリンク

これらは current user が確認できる文書ショートカットと最近見た文書を読むための導線であり、bookmark の作成・移動・削除とは分けて扱います。

## maintenance mode OFF

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり次の操作を許可します。

- favorite bookmark の作成
- read_later bookmark の作成
- read_later から favorite への移動
- favorite / read_later bookmark の解除

戻り先文脈、notice、保存済み filter、recent search、page params の扱いは既存 flow を維持します。

## 非目標

この boundary では次を扱いません。

- bookmark type の追加
- 最近見た文書の記録方式変更
- `RecentDocumentsQuery` の変更
- `AccessLog` の追加・変更
- 文書閲覧権限や readable scope の変更
- 文書ショートカット UI 全体の redesign
- 通知、SLA、共有 bookmark、全利用者向け変更系操作の一括停止

## 確認観点

- maintenance mode ON で `DocumentBookmark` が増えない
- maintenance mode ON で `お気に入りへ移す` が favorite 作成も read_later 削除も行わない
- maintenance mode ON で `解除` が bookmark を削除しない
- maintenance mode ON でも `GET /document_bookmarks` は 200 で確認できる
- maintenance mode OFF の既存作成 flow は壊れていない
