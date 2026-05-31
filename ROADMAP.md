# ROADMAP

## UI / UX 改善

### 導入済み基盤

- `tree_view` を更新し、今後の table / state 連携を取り込みやすい状態にする。
- `rails_table_preferences` を導入し、表示列、列幅、並び順、プリセットなどを保存できる基盤を用意する。
- `rails_fields_kit` を導入し、検索可能な select、tag、autocomplete など Tom Select と相性のよい入力補助を Rails helper + Stimulus controller 経由で使える基盤を用意する。
- Vite から gem 側 JavaScript entrypoint を読み込めるようにする。
- フロントエンド操作の方針を `Turbo のみ > Stimulus > 素の JavaScript` に寄せ、gem 提供 controller を使える状態にする。

### 次フェーズ: 実画面への gem 展開

導入済み基盤を、実際の管理画面や文書閲覧画面へ段階的に展開する。

#### 展開候補の現在地

| 領域 | 現在地 | 代表 issue / PR | 次に見る境界 |
| --- | --- | --- | --- |
| `rails_table_preferences` 一覧 | 実装済み代表画面あり | `admin/documents`, `admin/projects`, `admin/users`, `admin/external_folder_sync_sources`, `admin/document_sets` | 新しい一覧へ広げる前に、既存画面の column metadata、filter / preset、empty state、保存済み設定 smoke を確認する |
| `rails_fields_kit` フォーム | `admin/document_sets` が host app 側の実装済み代表例 | #1348 / PR #1366 で `document_set_items` の対象文書 local filter と fixed version selector の wiring を追加済み | remote search endpoint、table replacement、他フォームへの横展開は別 issue に分ける |
| `tree_view` 連携 | 候補整理段階 | 文書ツリーの展開状態、選択状態、表示列状態の保存候補 | ツリー UX と table state の責務境界が決まるまでは、実装済み current support として書かない |

`docs-portal` 側 issue では、画面固有の view、helper、route、params、Stimulus wiring、request / system spec を扱う。gem の public API、import path、controller registration、Vite alias 前提、導入手順の不足が論点になる場合は、upstream gem 側の issue / docs と分けて確認する。

新しい first slice が merge されたら、該当画面をこの表の「現在地」に反映し、open PR の番号だけが ROADMAP 上に残らないようにする。closed issue の網羅表にはせず、次に agent が見る判断材料だけを短く残す。

#### 一覧画面の `rails_table_preferences` 化

列が多い、または利用頻度が高い一覧から優先して、表示列、列幅、順序、フィルタ状態を保存できるようにする。

現時点で `rails_table_preferences` の editor / table / stable column key を持つ代表画面:

- `admin/documents`
- `admin/projects`
- `admin/users`
- `admin/external_folder_sync_sources`
- `admin/document_sets`

これらは新規展開候補ではなく、current main の実装済み代表画面として扱う。次の作業では、新しい一覧へ広げる前に、既存画面の column metadata、filter / preset、empty state、保存済み設定の代表 smoke を確認し、実装済み guard と未展開候補を issue 上で分ける。

#### フォームの `rails_fields_kit` 化

既存の select / text field / textarea を、必要に応じて `rails_fields_kit` helper へ置き換える。

特に件数が増えやすい選択欄は、Tom Select と remote search を前提に UX を改善する。

候補:

- project / company / user の選択
- document / document_version の選択
- document_set_items の文書選択
- 外部同期元や権限設定の関連レコード選択

Tom Select 自体は積極的に使う。ただし、アプリ側で `new TomSelect(...)` を直接増やすのではなく、`rails_fields_kit` helper と gem 提供 Stimulus controller に寄せる。

#### `tree_view` との連携強化

`tree_view`、`rails_table_preferences`、`rails_fields_kit` の連携を活かし、ツリー表示とテーブル表示の状態管理を一貫させる。

候補:

- 文書ツリーの展開状態、選択状態、表示列状態の保存
- ツリー + 詳細一覧の列幅や表示状態の保存
- `ResourceTableRenderState` 系の更新を docs-portal 側の文書閲覧 UX に反映

#### Stimulus 化の継続

既存の素の JavaScript 実装は、触るタイミングで Stimulus controller へ移す。

方針:

- Turbo で済むものは Turbo で実装する。
- ブラウザ上の小さな振る舞いは Stimulus controller に閉じ込める。
- `application.js` に `querySelectorAll` とイベント登録を直接増やさない。
- iframe 内 preview UI のような特殊処理は、実装モジュールと lifecycle controller を分けて管理する。

### 確認観点

- `vite build` が通ること。
- Rails system spec または手動確認で、主要導線の UX が維持されていること。
- table preference 保存がユーザー単位で期待どおり動くこと。
- Tom Select / remote search が大量データでも扱いやすいこと。
- gem 側に不足がある場合は、それぞれの gem リポジトリへ issue を作成する。
