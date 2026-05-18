# Archive preview spec

この仕様は、添付・元ファイル viewer における ZIP / archive preview の責務と今後の拡張方針を整理する。

## 現状の対象

- preview 対象は ZIP のみ
- `.tar` / `.gz` / `.tgz` など ZIP 以外の archive は download only とする
- ZIP preview 本体は展開せず、entry metadata のみ読み取る
- entry 本体 preview は text preview 候補に限定して専用画面で行う
- entry download は現時点では行わない

## 現状の UI

ZIP preview では以下を表示する。

- ZIP内サマリー
  - file 件数
  - folder 件数
  - text preview 候補 entry 件数
  - download 候補 entry 件数
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
  - safe / unsafe path
  - text preview 候補
  - download 候補または操作不可理由
  - text preview 候補への preview link
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
  - 安全性 filter
  - 候補 filter
  - 並び替え
  - コピー操作

## 操作

- entry path 検索
- directory filter
- file / folder filter
- safety filter
  - safe
  - unsafe path
- action candidate filter
  - text preview候補
  - download候補
  - 操作不可
- active filter summary
  - 検索語、directory、種別、安全性、候補条件を表示する
  - 各条件 chip から個別解除できる
- 種別 / path / size sort
- 条件リセット
- text preview候補 entry の preview link
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

そのため、metadata preview / path copy / directory filter の次は text entry preview だけを先に提供する。

### 実装しない条件

以下の条件に当てはまる entry は、entry 単位 preview / download の初期実装では扱わない。

- directory entry
- password protected / encrypted ZIP entry
- entry path が空、絶対 path、または `..` を含むもの
- nested archive と判定できるもの
- 設定した entry size 上限を超えるもの
- content type を安全に推定できないもの
- preview 可能種別に入らない binary entry

### 現在の action metadata

以下を entry metadata として持つ。

- `safe_path?`
- `actionable?`
- `action_unavailable_reason`
- `download_candidate?`
- `text_preview_candidate?`

現在の `download_candidate?` は、directory entry ではなく、かつ safe path であることだけを示す。
`text_preview_candidate?` は `download_candidate?` に加えて、拡張子が `.txt` / `.log` / `.md` / `.csv` / `.tsv` / `.json` / `.yaml` / `.yml` などのテキスト系であることを示す。

## entry 単位 action の初期実装

### URL / controller 境界

entry 単位 preview は、archive 本体の `DocumentFile` にぶら下がる専用 action とする。

実装済み:

- `GET /document_files/:public_id/archive_entries/preview?entry_path=...`

未実装:

- `GET /document_files/:public_id/archive_entries/download?entry_path=...`

controller では以下だけを担当する。

1. archive 本体の取得
2. archive 本体への閲覧権限確認
3. consent 確認
4. access log 記録
5. entry path parameter の受け取り
6. service 呼び出し
7. service result に応じた render

ZIP entry の探索、path validation、size validation、content type 推定は controller に置かない。

### service 境界

entry action は専用 service に分ける。

- `DocumentFileArchiveEntryLookup`
  - archive 本体と entry path を受け取る
  - safe path であることを確認する
  - ZIP 内で entry を探す
  - directory / missing / size over などを reason として返す
  - entry 本体は読み込まない
- `DocumentFileArchiveEntryPreview`
  - archive 本体と entry path を受け取る
  - lookup result を使って preview 可否を判定する
  - preview 対象だけ entry 本体を読み込む
  - UTF-8 validation と line count 上限を適用する
  - 例外を漏らさず Result として返す
- `DocumentFileArchiveEntryDownload`
  - 未実装
  - lookup result を受け取る
  - 初期実装では `send_data` 用の binary と filename / content_type を返す
  - 大容量 entry の streaming は後続検討にする

### 実装済みの lookup service

`DocumentFileArchiveEntryLookup` は実装済み。

現在の lookup result は以下を持つ。

- `entry_path`
- `found?`
- `directory?`
- `safe_path?`
- `previewable?`
- `downloadable?`
- `error?`
- `reason`
- `content_type`
- `filename`
- `size`

lookup の時点では entry content は読まず、metadata と action 可否だけを返す。
初期実装では、entry size が 1MB を超える場合は preview / download とも不可にしている。

### 実装済みの preview service

`DocumentFileArchiveEntryPreview` は実装済み。

現在の preview result は以下を持つ。

- `lookup`
- `entry_path`
- `filename`
- `content_type`
- `size`
- `text`
- `lines`
- `line_count`
- `truncated?`
- `line_limit`
- `previewable?`
- `error?`
- `reason`

preview service は lookup が `previewable?` の場合だけ entry 本体を読み込む。
entry 本体は UTF-8 として validation し、既定 2,000 行を超える場合は `truncated?` を true にする。

### 実装済みの preview UI

- text preview candidate の entry だけに preview link を表示する
- preview link 先では entry metadata と本文行を表示する
- 既存 text preview UI と同じ検索 / 一致行のみ表示 / コピー / reset を使う
- preview できない場合は reason を表示する
- download link はまだ表示しない

### 初期実装で許可する範囲

初期 preview では以下のみ許可する。

- safe path
- file entry
- text preview candidate
- entry size が設定上限以下
- UTF-8 として安全に読めるもの

### 権限の考え方

- archive 本体を閲覧できることは、entry を無制限に配信してよいことを意味しない
- entry download を追加する場合も、document file download 権限を再確認する
- preview だけを許可する場合は、既存の inline preview と同等の access log / consent timing を確認する
- entry 配信時にも元 archive file の access log に紐づけて記録できるようにする
