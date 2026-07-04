# 文書カタログ maintenance mode 境界

このメモは #4544 の first slice として、`READ_ONLY_MAINTENANCE` 中に文書カタログ管理で止める変更系操作と、止めずに read-only 確認として残す導線を整理する。

## 停止する操作

`READ_ONLY_MAINTENANCE` が有効な間、管理側の文書カタログ CRUD は開始しない。

- `Admin::DocumentCatalogsController#create`
  - catalog 基本項目を保存しない
  - catalog item 構成を同期しない
- `Admin::DocumentCatalogsController#update`
  - catalog 基本項目を更新しない
  - 既存 item の削除 / 再作成を実行しない
- `Admin::DocumentCatalogsController#destroy`
  - catalog を削除しない

停止時は `admin/document_catalogs` へ戻し、メンテナンス中のため作成・更新・削除を停止していることを alert で表示する。

## read-only として残す導線

maintenance mode 中も、次は確認用の read-only 導線として残す。

- 公開側 catalog 一覧 / 詳細
- 管理側 catalog 一覧
- 管理側 edit 画面での現在値確認
- 管理側 project remote search / selected project restore
- 管理側 document remote search / selected document restore

これらは catalog 保存、item 構成同期、catalog 削除を行わない確認導線として扱う。

## 非目標

この slice では次を変更しない。

- catalog visibility policy の再設計
- DocumentPermission / ProjectMembership / 文書ごとの visibility 判定
- 文書セット、文書ショートカット、文書一覧との使い分け
- item 一括編集、CSV import、drag/drop sort の追加
- DB schema、認可条件、外部 API 契約

## 確認観点

request spec では次を確認する。

- maintenance mode ON で create が `DocumentCatalog` / `DocumentCatalogItem` を増やさない
- maintenance mode ON で update が catalog 属性と item 構成を変更しない
- maintenance mode ON で destroy が catalog を削除しない
- maintenance mode ON でも管理側一覧・remote search・公開側 catalog 一覧 / 詳細が読める
- maintenance mode OFF の既存 create / update / public viewer flow を壊さない
