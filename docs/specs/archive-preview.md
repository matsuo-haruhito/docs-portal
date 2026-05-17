# Archive preview spec

この仕様は、添付・元ファイル viewer における ZIP / archive preview の責務と今後の拡張方針を整理する。

## 現状の対象

- preview 対象は ZIP のみ
- `.tar` / `.gz` / `.tgz` など ZIP 以外の archive は download only とする
- ZIP は展開せず、entry metadata のみ読み取る
- entry 本体の read / extract / download は現時点では行わない

## 現状の UI

ZIP preview では以下を表示する。

- ZIP内サマリー
  - file 件数
  - folder 件数
  - preview 対象 file の合計サイズ
- ディレクトリサマリー
  - ディレクトリ path
  - 直下 file 件数
  - 直下 folder 件数
  - 直下 file 合計サイズ
- entry 一覧
  - 種別
  - path
  - size
  - path copy 操作

## 表示上限

- preview は先頭 N entry のみを対象にする
- 上限を超える場合は truncated warning を表示する
- truncated 時は以下も先頭 N entry のみを対象にした結果であることを明示する
  - ZIP内サマリー
  - ディレクトリサマリー
  - 検索
  - 並び替え
  - コピー操作

## 操作

- entry path 検索
- file / folder filter
- 種別 / path / size sort
- 条件リセット
- entry path 個別コピー
- 表示中 entry path 一括コピー
- directory path 個別コピー

## 階層表示の方針

今後、entry path の階層表示を追加する場合は、既存の flat table を壊さず段階的に導入する。

推奨方針:

1. まず `DirectorySummary` を利用して、directory 単位の概要を表示する
2. 次に directory summary を折りたたみ可能にする
3. その後、選択した directory に属する entry だけを一覧に絞り込む
4. 最後に必要であれば tree view 表示を追加する

初期実装では、tree 構造をサーバーで深く組み立てすぎない。
entry path はそのまま保持し、UI 側では「directory filter」として扱うのが安全。

## entry 単位 preview / download の方針

entry 単位 preview / download は便利だが、以下の検討が必要。

- ZIP slip 対策
- password protected ZIP の扱い
- nested archive の扱い
- 大容量 entry の読み込み上限
- virus scan 済みファイル内 entry をどう扱うか
- download 権限と preview 権限の分離
- 一時ファイルを生成する場合の lifecycle

そのため、まずは metadata preview / path copy / directory filter までを優先する。
