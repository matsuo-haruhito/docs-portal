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
| `rails_table_preferences` 一覧 | 実装済み代表画面あり | `admin/documents`, `admin/projects`, `admin/users`, `admin/external_folder_sync_sources`, `admin/document_sets`, `admin/consent_terms`, `admin/document_usage_reports`, `admin/read_confirmations`。代表 smoke 固定候補は #1986 | 新しい一覧へ広げる前に、既存画面の column metadata、filter / preset、empty state、保存済み設定 smoke を確認する。これは pinned ref bump ではなく、実装済み画面を守る guard として扱う |
| `rails_fields_kit` フォーム | `admin/document_sets` が host app 側の実装済み代表例。案件選択は案件コード / 案件名の RFK remote search、対象文書は title / slug の RFK remote picker、既存 table row への移動・絞り込み、固定版 selector を current support として持つ。`admin/external_folder_sync_sources` では外部フォルダ同期設定の対象案件を案件コード / 案件名の RFK remote combobox で選び、保存済み・validation error 後の selected project 復元も扱う。`admin/document_usage_reports` と `admin/read_confirmations` では案件選択の `rfk_select` を利用済み | #1348 / PR #1366 は document set の local filter / fixed version selector。#1985 の文書 remote picker first slice は PR #2079 で clean branch から merge 済み。#2514 は文書セット案件選択 remote search の docs 同期。#3670 は外部フォルダ同期設定の project remote search docs 同期 | 文書権限の company / user selection、外部フォルダ同期設定以外の project selection 横展開は別 issue に分ける。文書セットの案件 remote search、対象文書 remote picker、fixed version selector、外部フォルダ同期設定の対象案件 remote search は current support として扱うが、他画面の project / company / user remote search と混ぜない |
| `tree_view` 連携 | 文書ツリー sidebar の current cue / 展開状態 first slice は実装済み。ツリー + table state 連携は候補整理段階。`ResourceTableRenderState` の文書閲覧 UX 反映は proposal/docs 境界整理段階 | #1984 / PR #2105 は merged。左ペインの current document ancestor 展開、表示中 badge、server-side 展開状態保存は current support。#4071 は `ResourceTableRenderState` 反映候補の surface / cue / evidence boundary 整理 | #1301 の pinned ref bump や upstream `tree_view` API 判断とは分ける。次はツリー + 詳細一覧の列幅 / 表示状態など table state 連携を proposal として切り分ける。#4071 では版詳細 / Docusaurus・Markdown viewer の table preference context cue を候補に置き、tree current cue、詳細一覧 filter / preset / column width、Markdown table full RTP integration とは混ぜない |

`docs-portal` 側 issue では、画面固有の view、helper、route、params、Stimulus wiring、request / system spec を扱う。gem の public API、import path、controller registration、Vite alias 前提、導入手順の不足が論点になる場合は、upstream gem 側の issue / docs と分けて確認する。

`#607` は screen-by-screen adoption、`#858` と child issue は pinned ref / smoke / rollback note の release train として読む。`#1300`、`#1301`、`#789` は target SHA や `Gemfile` / `Gemfile.lock` 更新を含む release train gate であり、この ROADMAP の展開候補表では current support として先取りしない。

新しい first slice が merge されたら、該当画面をこの表の「現在地」に反映し、open PR の番号だけが ROADMAP 上に残らないようにする。closed issue の網羅表にはせず、次に agent が見る判断材料だけを短く残す。

#### 一覧画面の `rails_table_preferences` 化

列が多い、または利用頻度が高い一覧から優先して、表示列、列幅、順序、フィルタ状態を保存できるようにする。

現時点で `rails_table_preferences` の editor / table / stable column key を持つ代表画面:

- `admin/documents`
- `admin/projects`
- `admin/users`
- `admin/external_folder_sync_sources`
- `admin/document_sets`
- `admin/consent_terms`
- `admin/document_usage_reports`
- `admin/read_confirmations`

これらは新規展開候補ではなく、current main の実装済み代表画面として扱う。次の作業では、新しい一覧へ広げる前に、#1986 のような guard first slice で既存画面の column metadata、filter / preset、empty state、保存済み設定の代表 smoke を確認し、実装済み guard と未展開候補を issue 上で分ける。

#### フォームの `rails_fields_kit` 化

既存の select / text field / textarea を、必要に応じて `rails_fields_kit` helper へ置き換える。

特に件数が増えやすい選択欄は、Tom Select と remote search を前提に UX を改善する。current main では `admin/document_sets` の案件選択で、案件コード / 案件名を使う remote search と保存済み・入力中の selected project 復元を使う。同じ画面の対象文書では、文書名 / URL 識別子を使う remote picker、既存 table row への移動・絞り込み、local filter、選択済みのみ表示、fixed version selector を組み合わせて使う。`admin/external_folder_sync_sources` では対象案件を案件コード / 案件名の remote combobox で検索し、編集画面や validation error 後も selected project を復元する。`admin/document_usage_reports` と `admin/read_confirmations` では案件選択で `rfk_select` を使う。これらは current support だが、文書権限の company / user selection、他フォームへの remote search 横展開、upstream RFK API 変更、pinned ref bump までは含めない。

候補:

- 文書権限の company / user の選択
- 外部フォルダ同期設定以外の関連レコード選択
- 文書セット・外部フォルダ同期設定以外の project selection 横展開

Tom Select 自体は積極的に使う。ただし、アプリ側で `new TomSelect(...)` を直接増やすのではなく、`rails_fields_kit` helper と gem 提供 Stimulus controller に寄せる。

#### `tree_view` との連携強化

`tree_view`、`rails_table_preferences`、`rails_fields_kit` の連携を活かし、ツリー表示とテーブル表示の状態管理を一貫させる。

候補:

- 実装済みの左ペイン文書ツリー展開状態 / current row cue を前提にした、詳細一覧側の列幅や表示状態の保存
- 文書ツリーの current cue と詳細一覧 filter / preset の責務境界整理
- `ResourceTableRenderState` 系の更新を docs-portal 側の文書閲覧 UX に反映する候補は、まず版詳細 / Docusaurus・Markdown viewer の table preference context cue に絞って確認する。viewer 内 table がどの文書版 / site path / table key / preference context を見ているかを読み返せる補助候補として扱い、tree current cue、詳細一覧 filter / preset / column width 連携、Markdown table full RTP integration とは分ける

#1984 / PR #2105 は merged 済みの current support として読む。左ペインの文書ツリーでは、user ごとの server-side preference による展開 / 折りたたみ保存、current document ancestor の展開、表示中 badge / `aria-current` による現在位置 cue を扱う。次の proposal は、これを前提にツリー + 詳細一覧の table state 連携を切り出し、#1301 の pinned ref bump や upstream `tree_view` public API 変更とは混ぜない。

`ResourceTableRenderState` の viewer 反映候補は #4071 で docs-only に境界を固定する。runtime 実装へ進める場合は、request/source spec か browser evidence のどちらで viewer context cue を guard するかを別 issue で決める。Gemfile / pinned ref、upstream API、viewer shell redesign、保存 schema、table preference persistence contract はこの候補整理には含めない。

#### Stimulus 化の継続

既存の素の JavaScript 実装は、触るタイミングで Stimulus controller へ移す。

現状確認と後続判断の入口は [フロントエンド初期化 inventory](./doc/frontend_initialization_inventory.md) です。inventory で `current support` として整理済みの controller / fallback path は、実装済みの挙動として維持し、後続候補は proposal として別 issue に分けます。

現在の読み分け:

- `preview-tools` bridge は移行用の入口として退役済み。`archive-preview-tools`, `csv-preview-tools`, `document-file-list-search`, `markdown-preview-document-search`, `markdown-preview-codeblock-tools`, `markdown-preview-table-tools`, `image-preview-tools`, `pdf-preview-tools`, `structured-preview-tools`, `site-viewer-iframe-height` などの専用 controller がそれぞれ helper refresh を担当する。bridge 再導入や空 controller の維持は current support として扱わない。
- `preview-table-resizer` は Markdown preview table の fallback path として維持する。Markdown table を `rails_table_preferences` へ寄せる判断は #475 の親論点に残す。
- `DocusaurusSiteRenderer` の table rewrite は current support として、site viewer HTML の `<table>` に `portal-doc-table-preference-wrapper` / `portal-doc-preference-table` と document version / site path / table index / stable table key metadata を付ける。これは後続 design / feature が参照できる DOM 境界であり、column visibility / preset UI / preference schema の最終判断は #475 に残す。
- `document-tree-navigation` は tree link click 後の Turbo Stream refresh を補助する app 側 controller として維持する。TreeView gem API、loading / error event 名、retry policy はこの ROADMAP で決めない。

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
