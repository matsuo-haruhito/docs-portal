# Preview UX roadmap

この文書は、Markdown / Docusaurus preview、版差分、添付・元ファイル viewer、検索、codeblock actions 周辺の改善ロードマップを整理する。

関連仕様の入口は [Specs index](../specs/README.md) を参照する。

## 現在までに入った主な改善

### Markdown / Docusaurus preview

- Rails viewer shell + same-origin iframe による Docusaurus HTML 表示
- iframe 内の Docusaurus navbar / footer / toc / sidebar 除去
- viewer toolbar から版詳細、差分、添付・元ファイルへ移動
- Markdown table toolbar
  - 表幅調整
  - 列幅調整
  - 先頭行固定
  - 先頭列固定
  - CSV / Markdown コピー
  - 表内検索
  - 表示設定リセット

### Version diff

- 添付・元ファイルの追加 / 変更 / 削除サマリ
- Markdown 行単位 diff
- レンダリング後 HTML diff
- HTML table cell diff
- 差分ビューのタブ風ナビゲーション / 件数バッジ
- 比較対象版 dropdown

### 添付・元ファイル viewer

- `DocumentFileViewerPlan` による viewer 種別判定
- 添付一覧への viewer label / preview 不可理由表示
- CSV / TSV preview
  - sample table 表示
  - 検索
  - CSV コピー
  - 先頭行固定
  - 先頭列固定
  - 列幅調整 / 保存 / リセット
- JSON / YAML preview
  - 整形表示
  - コピー
  - 内容検索
  - 一致行のみ表示
  - 検索ショートカット
- text preview
  - 先頭行表示制限
  - 検索
  - 一致行のみ表示
  - コピー
- image preview
  - inline 表示
  - fit / 原寸表示
  - zoom
  - rotate
  - keyboard shortcuts
- PDF preview
  - wrapper 画面
  - 表示高さ切り替え
  - keyboard shortcut
- ZIP preview
  - entry 一覧
  - entry 検索
  - entry path 個別コピー
  - 表示中 entry path 一括コピー
  - directory filter
  - file / folder filter
  - safety filter
  - candidate filter
  - active filter summary / 個別解除 chip
  - 件数サマリー
  - ディレクトリサマリー
  - ディレクトリパスコピー
  - safe / unsafe path 表示
  - entry action metadata / 操作候補表示
  - archive entry lookup service
  - archive entry text preview service
  - archive entry preview route / controller / view
  - archive entry preview request spec
  - archive entry download design
  - text preview candidate への preview link
  - text preview / download 候補分類
  - truncated 時の対象範囲 warning
  - entry sort
  - 条件リセット

### Controller / service structure

- `DocumentFilesController#show` の preview / send / not found 分岐整理
- Office preview rendering の helper 化
- embedded HTML preview / asset rendering の helper 化
- embedded asset path resolver service の切り出し
- embedded HTML base path helper の service 化
- inline preview の template dispatch / prepare dispatch 分離
- text inline preview predicate の切り出し
- preview service Result helper concern の追加
- `Content-Disposition` header 設定 helper 化

### Codeblock actions

- コードブロックコピー
- 言語ラベル表示
- 機密注意ラベル
- 行番号 / 行 anchor
- JSON codeblock のローカル構文検証
- JSON codeblock の整形コピー

### Search

- Docusaurus iframe 内の文書内検索
- 文書内検索UIの初期折りたたみ
- 文書内検索ショートカット
  - `/` で検索欄展開 / focus
  - `Enter` で次へ
  - `Shift+Enter` で前へ
  - `Esc` で解除 / 折りたたみ
- 添付・元ファイル一覧検索
- 添付・元ファイル検索で親フォルダ行を維持
- 添付・元ファイル検索で一致行 / 文脈行を区別表示

### Specs / research

- [Specs index](../specs/README.md)
- [検索責務仕様](../specs/search.md)
- [閲覧画面とUI仕様](../specs/閲覧画面とUI.md)
- [Archive preview仕様](../specs/archive-preview.md)
- [Docusaurus 実例調査メモ](../research/docusaurus-examples.md)
- DocumentFile viewer registry 仕様
- Preview target metadata 仕様
- Path history / redirect 仕様
- Codeblock actions 仕様
- Docusaurus build profiles 仕様

## 短期タスク

### 1. ZIP entry download の service 実装

目的:

- 設計済みの安全境界に沿って、UIへ出す前に download service と spec を固める

候補:

- `DocumentFileArchiveEntryDownload` service 追加
- binary data / filename / content_type / size を Result で返す
- unsafe / missing / directory / nested archive / size over を spec で固定する
- controller / route / UI は service が安定してから追加する

### 2. specs / roadmap の継続整理

目的:

- 実装済みの preview 改善と仕様書の差分を小さく保つ

候補:

- 仕様ファイル追加時に `docs/specs/README.md` へリンクする
- 実装済みタスクを roadmap から削除 / 移動する
- research と仕様の参照関係を整理する

## 中期タスク

### 1. Preview target metadata parser / validator

目的:

- `primary` / `attachments` / `hidden` / `debug` / `groups` を実際に検証できるようにする

候補:

- YAML metadata parser service
- glob path pattern validation
- 存在しない path の warning
- 重複指定の warning
- 通常表示ファイル 0 件の warning
- 品質チェック画面への表示

### 2. Path history / redirect 実装

目的:

- slug / site path / tree path 変更時に旧URL互換を保つ

候補:

- path history model
- canonical path resolver
- moved / archived / deleted notice
- 旧 path 参照の品質チェック warning
- slug / path 変更 dry-run

### 3. Docusaurus build profiles の明示化

目的:

- portal embedded / admin API spec / preview check / diff metadata の用途を分ける

候補:

- build command に profile を渡す
- build manifest を保存する
- manifest に profile / source commit / build time / validation result を含める
- stale build / profile mismatch warning を viewer shell に表示する

### 4. Codeblock action のレビューコメント接続

目的:

- code block の行 anchor と internal review comment を接続する

候補:

- comment form に codeblock anchor を入れられるようにする
- codeblock line からコメント追加を開始できるようにする
- コメント一覧から該当 codeblock line へ移動する

### 5. Portal 横断検索の第一歩

目的:

- dashboard / project 内で閲覧可能な文書・版・添付を検索できるようにする

候補:

- Project 内検索
- Document title / slug / tag / keyword / latest version summary 検索
- DocumentFile file name / tree path 検索
- 権限判定後の結果だけ表示

## 長期タスク

### 1. Full-text search index

目的:

- 文書本文、添付抽出テキスト、metadata を対象にした高速検索

候補:

- project / company / public / admin scope ごとの index 分離
- hidden / debug file の検索対象制御
- stale index warning
- Docusaurus build profile / diff metadata との連携

### 2. Office / PDF / image viewer 強化

目的:

- 添付・元ファイルの preview 体験をファイル種別ごとにさらに改善する

候補:

- Microsoft Graph Office preview の fallback 整理
- PDF.js 導入検討
- PDF page thumbnail / outline
- image thumbnail 生成
- image metadata / dimensions 表示
- text extraction metadata

### 3. External publish / standalone public build

目的:

- Rails portal 内 preview と外部公開用 Docusaurus build を分離する

候補:

- `standalone_public` profile
- public search
- canonical URL / redirect
- public-only index
- 公開前 preview check

### 4. Diff metadata build

目的:

- viewer runtime で重い解析を避ける

候補:

- heading index
- table index
- codeblock index
- internal link index
- HTML text extraction artifact
- version diff / search / review anchor への再利用

## 実装順のおすすめ

1. ZIP entry download service / spec
2. ZIP entry download route / controller / request spec
3. ZIP entry download UI link
4. Preview target metadata parser / validator
5. Docusaurus build manifest
6. Path history resolver
7. Project 内検索
