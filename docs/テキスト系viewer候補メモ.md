# テキスト系viewer候補メモ

この文書は issue `#263` に対応する、JSON / YAML / plain text 向け OSS viewer 候補の整理メモです。

## 1. 結論

- 初期の Rails 側 text preview は `highlight.js` または `Shiki` のような「静的ハイライト寄り」を優先する
- 行番号、検索、折りたたみ、将来のコメント位置連携まで必要になったら `CodeMirror 6` を第一候補にする
- JSON の tree / code / text 切替が必要な画面だけ `jsoneditor` を限定採用候補にする
- `Monaco Editor` は機能は強いが、現行の Rails + Hotwire + importmap 中心構成には重いので初期既定にはしない

## 2. 比較観点

- readonly viewer として使いやすいか
- JSON / YAML / plain text を無理なく扱えるか
- 行番号、検索、折りたたみ、コピー、diff への発展性があるか
- Rails / Hotwire 構成へ組み込みやすいか
- CSS 衝突や bundle サイズのリスクが大きすぎないか

## 3. 候補整理

### CodeMirror 6

- 強み:
  - read-only を明示設定できる
  - line numbers / fold gutter / search など editor 拡張が揃っている
  - JSON / YAML / plain text の viewer を同一系統で揃えやすい
  - 将来の行番号ベースコメントや diff 連携へ伸ばしやすい
- 弱み:
  - npm / bundler 前提で、importmap 中心の現状には一段重い
  - viewer だけ欲しい場合にはオーバースペックになりやすい
- 採用判断:
  - Rails 側 text preview を本格 viewer に育てる段階の第一候補

### Monaco Editor

- 強み:
  - VS Code 系の editor 体験に近く、検索・折りたたみ・言語対応が強い
  - large file viewer としても有力
- 弱み:
  - bundle / loader / worker 周りが重い
  - 現行の Rails + Hotwire 構成には導入コストが高い
- 採用判断:
  - 「viewer より editor 寄り」が必要になった時の後続候補

### Shiki

- 強み:
  - VS Code 系 TextMate grammar ベースで見た目がよい
  - zero runtime 寄りに使え、静的 HTML へ落としやすい
  - line highlight など transform 拡張がしやすい
- 弱み:
  - 行番号、検索、折りたたみは viewer 本体機能としては持たない
  - 構造化 JSON tree のような UI は別途必要
- 採用判断:
  - まず読みやすいハイライトだけを付けたい時の有力候補

### highlight.js

- 強み:
  - 軽量で導入しやすい
  - auto-detection と多数言語対応がある
  - plain text を含む code block viewer として扱いやすい
- 弱み:
  - 高度な折りたたみ、検索、行ベース interaction は弱い
  - JSON / YAML を「構造として見る」用途には向かない
- 採用判断:
  - 最初の Rails preview に最も入れやすい候補

### jsoneditor

- 強み:
  - JSON を tree / code / text などの mode で見られる
  - JSON 専用 viewer としては使い勝手がよい
- 弱み:
  - YAML / plain text へはそのまま広げにくい
  - 汎用 viewer の中核にするより、JSON 専用 widget として使う方が自然
- 採用判断:
  - JSON 詳細画面だけ別扱いしたい場合の限定候補

## 4. 推奨方針

### 初期実装

- Rails 側 preview は server-rendered HTML を基本にする
- plain text / YAML / JSON の見た目改善は `highlight.js` か `Shiki` を優先する
- 行番号は CSS + server-side 分割で最低限付ける
- コメント位置情報や diff 連携が必要になるまでは、重い editor component を既定にしない

### 後続強化

- 行番号ジャンプ、検索、fold、位置コメント連携が必要になった段階で `CodeMirror 6` を導入候補に上げる
- JSON の tree 表示要求が強ければ、その画面だけ `jsoneditor` を追加検討する
- `Monaco Editor` は本格 editor 需要が出た時だけ再評価する

## 5. ライセンスと導入感

- `CodeMirror 6`: MIT 系
- `Monaco Editor`: MIT
- `Shiki`: MIT
- `highlight.js`: BSD-3-Clause
- `jsoneditor`: Apache-2.0

いずれも OSS としては導入可能だが、`Monaco Editor` はライセンスより運用コストが先に問題になりやすいです。

## 6. docs-portal での暫定判断

- 既定 viewer:
  - Markdown / MDX: Docusaurus viewer
  - JSON / YAML / plain text: Rails preview + 軽量ハイライト
- 第一段階の実装候補:
  - `highlight.js`
- 第二段階の実装候補:
  - `CodeMirror 6`
- JSON 専用の強化候補:
  - `jsoneditor`

## 7. close 条件との対応

- テキスト系 viewer 候補の比較: 本文 3 章で整理済み
- JSON / YAML / plain text ごとの推奨方針: 本文 4 章で整理済み
- Rails / Hotwire 構成への組み込み可否: 本文 3-4 章で整理済み
- ライセンス懸念: 本文 5 章で整理済み
