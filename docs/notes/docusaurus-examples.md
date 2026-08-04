# Docusaurus 実例調査メモ

このメモは、Docusaurus を実運用している公開リポジトリから、docs-portal に転用できそうな構成・UI・運用パターンを整理するためのものです。

## 調査の目的

- docs-portal の Docusaurus viewer / preview / diff / artifact 表示を改善する
- Docusaurus の標準機能と、各プロジェクトの実運用上の工夫を分けて把握する
- 実装前に、取り込む価値が高いパターンを優先順位づけする

## 調査対象

### Samsung/qaboard

リポジトリ: `Samsung/qaboard`

特徴:

- Experiment tracking framework の documentation site
- Docusaurus v2 beta 系
- GitHub Pages 公開と Web アプリ内埋め込み用 build profile を切り替えている
- advanced viewers / artifact visualization / diff / comparison の思想が docs-portal に近い

参考になりそうな点:

- Docusaurus build profile を用途別に切り替える
  - 通常公開用
  - Web アプリ内 `/docs/` 埋め込み用
- 表示対象ファイルを宣言する visualization 設計
- file extension / type に応じた viewer registry の考え方
- debug visualization を `default_hidden` として扱い、利用者が必要に応じて表示する導線
- dynamic path pattern による表示対象の切り替え
- 画像、Plotly、Flame Graph、HTML、Video、Text など複数 viewer の併用

### webdriverio/webdriverio website

リポジトリ: `webdriverio/webdriverio`

特徴:

- Docusaurus v3 系の大規模 docs site
- TypeScript config
- i18n
- 複数 docs plugin
- redirect 管理
- Algolia search
- PWA / ideal image
- docs 生成前処理
- version dropdown

参考になりそうな点:

- `docusaurus.config.ts` による型付き設定
- build / start 前の docs 生成処理
- strict link check
- i18n / locale dropdown
- 複数 docs plugin による route 分割
- version dropdown による旧版 docs への導線
- client redirects による旧URL互換
- codeblock action / Run Example のような実行・コピー導線
- PWA / ideal-image による閲覧体験の改善

## 横断調査の検索軸

GitHub code search では、単に `docusaurus.config.ts` で探すだけでは対象が多すぎるため、次のように目的別に検索する。

### 複数 docs / route 分割

```text
"docusaurus.config.ts" "content-docs" "routeBasePath"
```

見る観点:

- 通常 docs と API docs を分けているか
- community / guide / reference などを別 plugin にしているか
- sidebar を docs 空間ごとに分けているか

### バージョン切り替え

```text
"docusaurus.config.ts" "pastVersions"
"docusaurus.config.ts" "versionDropdown"
"docusaurus.config.ts" "versions"
```

見る観点:

- navbar で旧版をどう表示しているか
- 現行版と旧版の URL をどう分けているか
- 古い版に warning / notice を出しているか

### redirect / slug 移行

```text
"docusaurus.config.ts" "client-redirects"
"docusaurus.config.ts" "redirects"
```

見る観点:

- 古い path をどう新 path へ誘導しているか
- v7 -> v8 のような version migration をどう扱うか
- slug rename の互換性をどう保つか

### docs 生成前処理

```text
"package.json" "docs:generate" "docusaurus"
"docusaurus.config.ts" "generate"
```

見る観点:

- API reference や generated docs を build 前に作っているか
- generated docs を source とどう分離しているか
- CI / local preview の双方で同じ手順にしているか

### 検索

```text
"docusaurus.config.ts" "algolia"
"docusaurus.config.ts" "theme-search-algolia"
"docusaurus.config.ts" "mendable"
```

見る観点:

- Docusaurus 内検索とアプリ側検索の責務分離
- 権限付き文書で検索 index をどう扱うか
- 検索結果から viewer shell へどう戻すか

### codeblock / command UX

```text
"docusaurus.config.ts" "codeblock"
"docusaurus.config.ts" "Run Example"
"docusaurus.config.ts" "remark-plugin-npm2yarn"
```

見る観点:

- コマンド例のコピー
- npm/yarn/pnpm の切り替え
- API sample の実行導線
- curl / JSON / YAML のコピー操作

### 画像最適化 / offline

```text
"docusaurus.config.ts" "ideal-image"
"docusaurus.config.ts" "plugin-pwa"
```

見る観点:

- 大きい画像をどう軽量化しているか
- lazy load / responsive image の扱い
- offline / installable docs の必要性

## docs-portal への適用候補

### 1. Docusaurus build profile の明確化

現状の docs-portal は Docusaurus 生成済み HTML を Rails viewer shell に埋め込む構造を持つ。
今後は build profile を明示的に分けるとよい。

候補:

- standalone public build
- portal iframe embedded build
- admin/API spec build
- preview/diff metadata build

期待効果:

- viewer shell 向けに navbar / footer / sidebar を削る前提を明確化できる
- broken link check や baseUrl を用途ごとに切り替えやすくなる
- 将来の external publish と internal preview を分けやすい

### 2. DocumentVersion の任意版比較 dropdown

webdriverio の version dropdown 的な発想を、docs-portal の `DocumentVersion` に落とし込む。

候補:

- 版詳細に比較対象版 dropdown を追加
- デフォルトは直前閲覧可能版
- 任意版との Markdown diff / HTML diff / table cell diff を表示
- 最新版以外を見ている場合は warning を出す

期待効果:

- 「前版との差分」だけでなく、任意の古い版との差分を確認できる
- レビューや外部送付前確認で使いやすくなる

### 3. DocumentFile viewer registry

qaboard の viewer registry 的な考え方を、docs-portal の添付・元ファイル preview に導入する。

候補:

| 種別 | viewer |
| --- | --- |
| Markdown | HTML preview / diff |
| HTML | same-origin iframe |
| PDF | PDF preview |
| Office | Microsoft Graph / Google Drive fallback |
| CSV / TSV | table viewer |
| JSON / YAML | code viewer / tree viewer |
| Image | image viewer |
| Text / log | text viewer / diff |
| ZIP | archive tree |

期待効果:

- 添付・元ファイルの preview 方針を一元化できる
- 新 viewer の追加がしやすくなる
- UI 文言や fallback を揃えられる

### 4. 表示対象宣言 metadata

qaboard の visualization config のように、文書版ごとに「どのファイルをどう見せるか」を宣言できるようにする。

例:

```yaml
preview:
  primary: docs/index.md
  attachments:
    - specs/*.pdf
    - tables/*.csv
  hidden:
    - debug/*
  groups:
    - name: API仕様
      paths:
        - api/*.md
    - name: 参考資料
      paths:
        - references/*
```

期待効果:

- 添付が多い案件でも利用者向けに整理できる
- debug / internal / generated artifact をデフォルト非表示にできる
- 文書セットやカタログとの接続がしやすくなる

### 5. old path redirect / slug history

webdriverio の client redirects 的な考え方を、文書 slug / path の変更に応用する。

候補:

- Document path history
- old slug -> current document redirect
- moved notice
- deleted / archived document の代替先表示

期待効果:

- 外部共有済みURLを壊しにくくなる
- 文書再編に強くなる

### 6. codeblock action

API仕様や手順書で、コードブロックに操作を付ける。

候補:

- curl コピー
- JSON コピー
- YAML コピー
- API import dry-run
- コマンド例コピー

期待効果:

- API仕様ページの実用性が上がる
- 管理者向け手順書が使いやすくなる

### 7. 検索責務の整理

Docusaurus の全文検索と Rails 側の権限付き検索は責務を分ける必要がある。

候補:

- Docusaurus iframe 内検索: 現在開いている文書内の検索
- Rails 検索: 権限付きの案件横断検索
- 将来の検索 index: project / company / public scope ごとに分離

期待効果:

- 権限漏れを避けながら検索 UX を改善できる
- iframe viewer と portal navigation の役割が明確になる

## 優先順位

### 短期

1. DocumentVersion の任意版比較 dropdown
2. DocumentFile viewer registry の仕様化
3. old path redirect / slug history の仕様化

### 中期

4. 表示対象宣言 metadata
5. codeblock action
6. build profile の明確化

### 長期

7. i18n / locale 設計
8. PWA / offline
9. image optimization

## 次のPR候補

### 任意版との差分比較 dropdown

内容:

- 版詳細で比較対象版を選択できるようにする
- query parameter で compare target を保持する
- Markdown diff / HTML diff / table cell diff の比較対象を切り替える

理由:

- 既存の diff viewer と相性がよい
- webdriverio の version dropdown 的な発想を docs-portal の DocumentVersion に直接活かせる
- 編集保存に入る前の安全な UX 改善になる

### DocumentFile viewer registry 仕様

内容:

- 添付・元ファイルの viewer 選択ルールを仕様化する
- Office preview、PDF、HTML、Markdown、CSV、JSON、画像、テキスト、ZIP の fallback を整理する

理由:

- qaboard の advanced viewers / visualization registry からの学びを活かせる
- 今後のファイル preview 拡張の土台になる
