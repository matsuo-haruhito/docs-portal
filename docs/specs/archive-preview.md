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
  - directory path copy 操作
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
  - directory filter
  - 種別 filter
  - 並び替え
  - コピー操作

## 操作

- entry path 検索
- directory filter
- file / folder filter
- 種別 / path / size sort
- 条件リセット
- entry path 個別コピー
- 表示中 entry path 一括コピー
- directory path 個別コピー

## 階層表示の方針

今後、entry path の階層表示を追加する場合は、既存の flat table を壊さず段階的に導入する。

現在は、tree view の代わりに directory summary と directory filter を提供する。
entry path はそのまま保持し、UI 側では「directory filter」として扱う。

推奨方針:

1. `DirectorySummary` を利用して、directory 単位の概要を表示する
2. directory filter で選択した directory 直下の entry だけを一覧に絞り込む
3. 必要になったら directory summary を折りたたみ可能にする
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

### 実装しない条件

以下の条件に当てはまる entry は、entry 単位 preview / download の初期実装では扱わない。

- directory entry
- password protected / encrypted ZIP entry
- entry path が空、絶対 path、または `..` を含むもの
- nested archive と判定できるもの
- 設定した entry size 上限を超えるもの
- content type を安全に推定できないもの
- preview 可能種別に入らない binary entry

### 初期実装ステップ案

1. entry path validator を service と spec で追加する
2. entry metadata に `previewable` / `downloadable` / `reason` を持たせる
3. UI ではまず disabled action と reason 表示だけを出す
4. download は一時ファイルを作らず streaming できるか検討する
5. preview は text / JSON / CSV など小さいテキスト entry に限定して検討する

### 権限の考え方

- archive 本体を閲覧できることは、entry を無制限に配信してよいことを意味しない
- entry download を追加する場合も、document file download 権限を再確認する
- preview だけを許可する場合は、既存の inline preview と同等の access log / consent timing を確認する
- entry 配信時にも元 archive file の access log に紐づけて記録できるようにする
