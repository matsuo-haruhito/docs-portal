---
name: "tree_view実装ガイド"
description: "docs-portalでtree_view-rails (v1.0.1) を使うための実装パターン。PathTreeBuilder・GraphAdapter の使い分け、folder_key_resolver、CSS分離、view partialの書き方。"
inclusion: manual
---
# tree_view-rails 実装ガイド

## 採用バージョンと公開API

- gem: `tree_view-rails` v1.0.1（tag固定）
- Vite alias: `tree_view` → gem の `app/javascript/tree_view/index.js`（package root）
- CSS: gem baseline `tree_view.css` + host override `docs_portal_tree_view.css`
- TypeScript型: `app/frontend/types/tree_view.d.ts`（gem同梱 `index.d.ts` ベース）

---

## ツリー構築パターンの選択

### PathTreeBuilder（path-based tree）

ファイルパスのような「区切り文字で階層を表す文字列」からツリーを構築する場合に使う。

**適用場面**:
- 文書の source_directory（`guides/detail/intro`）からフォルダ階層を作る
- document_file の `tree_path`（`src/docs/README.md`）から表示ツリーを作る
- 1つのリソース種別を path で階層化する場面

**代表実装**:
- `DocumentFilePresentation::TreeBuilder` — document_file の添付ファイルツリー
- `ProjectsHelper#project_document_detail_path_tree_builder` — 案件内の文書ツリー

```ruby
builder = TreeView::PathTreeBuilder.new(
  records: documents,
  path_resolver: ->(doc) { "#{document_tree_source_directory(doc)}/#{doc.title}" },
  label_resolver: ->(doc) { tree_item_label(doc) },
  id_resolver: ->(doc) { "document_#{doc.id}" },
  folder_key_resolver: ->(segments) {
    path = segments.join("/")
    "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
  },
  sort: { folders_first: true }
)

tree = builder.tree
root_items = tree.root_items
```

### GraphAdapter（異種ルート・手動構造）

Project / Folder / Document のように**異なる型のノード**が混在するツリーに使う。

**適用場面**:
- サイドバー文書ツリー（Project → Folder → Document の多段構造）
- 複数の root 型（Project がルート、Folder/Document が子）
- children の解決が型ごとに異なる

**代表実装**:
- `DocumentsHelper#document_tree_render_state` — サイドバーの文書ツリー

```ruby
adapter = TreeView::GraphAdapter.new(
  roots: projects,
  children_resolver: ->(node) {
    case node
    when Project then document_tree_nodes_for(node)
    when DocumentTreeFolderNode then node.children
    else []
    end
  },
  node_key_resolver: ->(node) { node_key(node) }
)

tree = TreeView::Tree.new(adapter:)
```

### 選択基準まとめ

| 条件 | 使うもの |
|------|---------|
| path文字列からフォルダ階層を生成する | `PathTreeBuilder` |
| 複数の型がルートと子に混在する | `GraphAdapter` |
| PathTreeBuilder で作った subtree を上位の GraphAdapter に組み込む | 両方併用 |

---

## PathTreeBuilder のノード型

`PathTreeBuilder` が生成するノードは以下の Struct:

| 型 | 主要メソッド | 用途 |
|---|---|---|
| `TreeView::PathTreeBuilder::FolderNode` | `.key`, `.parent_key`, `.label`, `.path`, `.node_type`, `.folder_node?`, `.record_node?` | 自動生成されたフォルダ |
| `TreeView::PathTreeBuilder::RecordNode` | `.key`, `.parent_key`, `.label`, `.path`, `.record`, `.node_type`, `.folder_node?`, `.record_node?` | 元レコードのラッパー |

### view partial での型判定

```slim
- if item.folder_node?
  strong = item.label
- else
  - record = item.record
  = link_to record.title, some_path(record)
```

`is_a?` ではなく `.folder_node?` / `.record_node?` を使う。

---

## folder_key_resolver — 既存 expanded_keys との互換性

`TreeViewState` にユーザーの展開状態が永続化されている場合、key形式を変えると既存の保存済み expanded_keys が無効になる。

**ルール**: 既存画面を PathTreeBuilder へ移行するときは、元の key 生成ロジックを `folder_key_resolver` で再現する。

```ruby
# 元のkey: "project_detail_folder_{project_id}_{sha256(path).first(16)}"
folder_key_resolver: ->(segments) {
  path = segments.join("/")
  "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
}
```

新規画面で互換性を気にする必要がない場合は `folder_key_resolver` を省略してよい。デフォルトは `TreeView.node_key(folder_key_prefix, path)` 形式。

---

## sort の指定

PathTreeBuilder のデフォルト sorter は `sort: { folders_first: true }` でフォルダ優先 → label昇順。

カスタム sort が必要な場合:

```ruby
TreeView::PathTreeBuilder.new(
  records: files,
  path_resolver: ->(file) { file.tree_path },
  sorter: ->(items, _tree) {
    items.sort_by { |item| [item.folder_node? ? 0 : 1, item.label.to_s.downcase] }
  }
)
```

**ルール**:
- 入力配列の事前 sort だけに頼らない — `PathTreeBuilder` / `Tree` が最終的に sorter を通す
- sorter を明示しない場合は `sort: { folders_first: true }` を推奨

---

## CSS の責務分離

| ファイル | 所有者 | 内容 |
|---------|--------|------|
| `tree_view.css`（gem 提供） | upstream | toggle cell、branch lines、toolbar 等の構造的CSS |
| `app/assets/stylesheets/docs_portal_tree_view.css` | host app | 色、サイズ、間隔、sidebar レイアウト等のアプリ固有override |

### ルール

- gem baseline と同じ logical name（`tree_view.css`）をhost側で持たない
- host の override CSS を `docs_portal_tree_view.css` に置く
- レイアウトでは `stylesheet_link_tag "tree_view"` の後に `stylesheet_link_tag "docs_portal_tree_view"` を読み込む
- TreeView の構造的CSS（toggle cell の display、branch line の position）をhost側にコピーしない

---

## RenderState の組み立て

```ruby
TreeView::RenderState.new(
  tree:,
  root_items: tree.root_items,
  row_partial: "projects/document_detail_tree_columns",
  ui_config:,
  tree_instance_key: "documents:project_detail:#{project.id}",
  initial_expansion: {
    default: :collapsed,
    expanded_keys:,
    collapsed_keys: []
  },
  toggle_icon_builder: ->(item, state, context) { ... },
  row_class_builder: ->(item) { ... }
)
```

- `tree_instance_key` は永続化用の一意キー
- `initial_expansion` で展開状態を制御
- `toggle_icon_builder` / `row_class_builder` はアプリ固有のUI表現

---

## Stimulus 登録

```typescript
// app/frontend/entrypoints/application.ts
import { registerTreeViewControllers } from "tree_view"
registerTreeViewControllers(application)
```

- gem の package-root export `registerTreeViewControllers` を使う
- raw event 名や controller identifier を文字列で写経しない
- gem 内部 path を import しない

---

## 展開状態の永続化

- `TreeViewStateOwner` concern を User モデルに include
- `TreeViewState` モデルが `owner + tree_instance_key` で expanded_keys を保存
- 展開/折りたたみは Turbo Stream で部分更新し、同時に TreeViewState を更新

---

## やらないこと

- 自前のネスト表示（recursive partial）を実装しない
- `app/javascript/tree_view/` 配下の内部ファイルを直接 import しない
- gem の構造的CSS をhost CSS にコピーしない
- 新規画面で既存の `DocumentTreeFolderNode` (Data.define) パターンを増やさない — PathTreeBuilder を使う
- sidebar tree（DocumentsHelper）の GraphAdapter 構成を無理に PathTreeBuilder へ変更しない（異種ルートのため GraphAdapter が適切）

---

## チェックリスト: 新しいツリー画面

1. path-based か異種ルートかで `PathTreeBuilder` / `GraphAdapter` を選ぶ
2. `tree_instance_key` を決めて `TreeViewStateOwner` で永続化
3. `RenderState` を helper で組み立て、view で `tree_view_rows` / `tree_view_toolbar` を使う
4. row partial では `.folder_node?` / `.record_node?` で分岐
5. 展開/折りたたみは Turbo Frame + Turbo Stream
6. CSS override は `docs_portal_tree_view.css` に追記
7. sorter を明示（`sort: { folders_first: true }` またはカスタム）
8. 既存画面移行時は `folder_key_resolver` で key 互換性を維持
