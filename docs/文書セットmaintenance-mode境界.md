# 文書セット maintenance mode 境界

このメモは #4547 の first slice として、`READ_ONLY_MAINTENANCE` 中に文書セット管理で止める変更系操作と、止めずに read-only 確認として残す導線を整理する。

## 停止する操作

`READ_ONLY_MAINTENANCE` が有効な間、管理側の文書セット CRUD は開始しない。

- `Admin::DocumentSetsController#create`
  - 文書セット基本項目を保存しない
  - 対象文書 item 構成を同期しない
  - 固定版指定を保存しない
- `Admin::DocumentSetsController#update`
  - 文書セット基本項目を更新しない
  - 既存 item の削除 / 再作成を実行しない
  - 固定版指定を変更しない
- `Admin::DocumentSetsController#destroy`
  - 文書セットを削除しない

停止時は `admin/document_sets` へ戻し、メンテナンス中のため作成・更新・削除を停止していることを alert で表示する。

## read-only として残す導線

maintenance mode 中も、次は確認用の read-only 導線として残す。

- 管理側の文書セット一覧
- 一覧 filter、CSV 出力、CSV 条件 metadata JSON
- 管理側 project / document / document version remote search
- 管理側 edit 画面での現在値確認
- 公開側の文書セット一覧 / 詳細

これらは文書セット保存、item 構成同期、固定版変更、削除を行わない確認導線として扱う。

## 非目標

この slice では次を変更しない。

- DocumentSet model / DocumentSetItem schema
- visibility policy、固定版 / 最新版 contract
- 外部送付 workflow、通知、retry、ack
- bulk 操作、CSV import、文書セット画面 redesign
- DB schema、認可条件、外部 API 契約

## 確認観点

request spec では次を確認する。

- maintenance mode ON で create が `DocumentSet` / `DocumentSetItem` を増やさない
- maintenance mode ON で update が基本項目と item 構成を変更しない
- maintenance mode ON で destroy が文書セットを削除しない
- maintenance mode ON でも一覧、CSV、JSON metadata、search、公開側一覧 / 詳細が読める
- maintenance mode OFF の既存 destroy flow を壊さない
