# Preview UX roadmap

この文書は、Markdown / Docusaurus preview、版差分、添付・元ファイル viewer、検索、codeblock actions 周辺の改善ロードマップを整理する。

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

### Version diff

- 添付・元ファイルの追加 / 変更 / 削除サマリ
- Markdown 行単位 diff
- レンダリング後 HTML diff
- HTML table cell diff
- 比較対象版 dropdown

### Codeblock actions

- コードブロックコピー
- 言語ラベル表示
- 機密注意ラベル
- 行番号 / 行 anchor
- JSON codeblock のローカル構文検証

### Search

- Docusaurus iframe 内の文書内検索
- 文書内検索ショートカット
  - `/` で検索欄 focus
  - `Enter` で次へ
  - `Shift+Enter` で前へ
  - `Esc` で解除
- 添付・元ファイル一覧検索
- 添付・元ファイル検索で親フォルダ行を維持
- 添付・元ファイル検索で一致行 / 文脈行を区別表示

### Specs / research

- Docusaurus 実例調査メモ
- DocumentFile viewer registry 仕様
- Preview target metadata 仕様
- Path history / redirect 仕様
- Codeblock actions 仕様
- Docusaurus build profiles 仕様
- 検索責務仕様

## 短期タスク

### 1. 添付・元ファイル viewer registry の第一歩

目的:

- 添付一覧の操作列を file type 判定に寄せる
- 今後の PDF / CSV / JSON / Office viewer 拡張の土台にする

候補:

- `DocumentFileViewerPlan` service / presenter を追加
- Markdown / HTML / PDF / Office / text / download only の最小判定を実装
- 版詳細の添付一覧で viewer plan に応じた label / action を出す
- preview 不可理由を UI に表示する

### 2. CSV / TSV viewer

目的:

- 表形式ファイルをブラウザ上で見やすくする
- Markdown table toolbar の UX を添付ファイルにも広げる

候補:

- CSV / TSV を sample preview として表示
- 大容量時は先頭 N 行だけ表示
- 検索 / コピー / 列幅調整を再利用
- download 権限がある場合は download 導線も残す

### 3. 文書内検索UIの折りたたみ

目的:

- iframe 内の検索バーが常時表示で本文を圧迫しすぎないようにする

候補:

- 初期状態では小さい「文書内検索」ボタンだけ表示
- `/` またはクリックで検索バーを展開
- `Esc` で検索解除 + 折りたたみ
- モバイル幅での表示を調整

### 4. Codeblock JSON 整形コピー

目的:

- API仕様や import API sample の利用性を上げる

候補:

- JSON codeblock に「整形コピー」ボタンを追加
- `JSON.parse` + `JSON.stringify(value, null, 2)` で整形
- invalid JSON の場合は既存の JSON検証エラーを表示

### 5. 検索仕様と既存UIのリンク整理

目的:

- `docs/specs/search.md` と既存UI仕様の参照関係を明確にする

候補:

- `docs/specs/README.md` を追加
- 検索、閲覧画面、API、権限、外部連携などの仕様入口を整理
- roadmap から関連仕様へリンクする

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

- 添付・元ファイルの preview 体験をファイル種別ごとに改善する

候補:

- Microsoft Graph Office preview
- Google Drive fallback
- PDF preview
- image preview / resize
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

1. `DocumentFileViewerPlan` の最小実装
2. CSV / TSV viewer
3. `docs/specs/README.md` 追加
4. Preview target metadata parser / validator
5. Docusaurus build manifest
6. Path history resolver
7. Project 内検索

## 方針

- 編集保存はまだ後回しにする
- まず preview / diff / search / viewer の閲覧体験を固める
- サーバー連携 action は copy / local validation より慎重に扱う
- 権限境界を越える検索・preview・redirect は必ず Rails route と権限判定を通す
- Docusaurus iframe 内で完結する操作は、same-origin 前提で強化しつつ、cross-origin でも壊れない fallback を維持する
