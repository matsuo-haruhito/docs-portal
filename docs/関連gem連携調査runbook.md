# 関連 gem 連携調査 runbook

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` が関わる issue を調べるときの入口を 1 本にまとめた runbook です。

`doc/frontend_interaction_policy.md` が方針の正本、この文書が「最初にどのローカルファイルと upstream docs を見るか」の運用導線です。

## 先に確認する共通ファイル

- `Gemfile`
  - 3 gem の取り込み元を確認する
- `app/frontend/entrypoints/application.js`
  - Stimulus controller の登録状況を確認する
- `vite.config.ts`
  - gem 同梱 JavaScript を Vite からどう解決しているかを確認する
- `doc/frontend_interaction_policy.md`
  - app 側責務と gem 側責務の切り分けを確認する
- `docs/開発・保守ガイド.md`
  - repo 全体の読み進め方と依存 gem の採用理由を確認する

## tree_view

### 主な責務

- 文書ツリーや詳細ツリーの render state、row 描画、開閉操作の基盤を担います。
- 文書や案件の query、権限制御、業務ラベル、表示条件は `docs-portal` 側責務です。

### docs-portal 側の主な確認場所

- `app/helpers/documents_helper.rb`
  - サイドバーの文書ツリー生成、folder node、icon 判定、HTML 表示可否、toggle path を確認する
- `app/helpers/projects_helper.rb`
  - 文書詳細ページ側の tree render state と folder node 構築を確認する
- `app/views/documents/_tree.html.erb`
  - サイドバー側の table / spacer / toolbar / `tree_view_rows` 呼び出しを確認する
- `app/views/projects/_document_detail_tree.html.erb`
  - 文書詳細側の table / toolbar / `tree_view_rows` 呼び出しを確認する
- `app/views/layouts/application.html.slim`
  - sidebar layout と `data-controller="sidebar"` まわりを確認する
- `app/controllers/projects_controller.rb`
  - `document_tree` / `document_detail_tree` の request 入口を確認する
- `app/models/concerns/tree_view_state_owner.rb`
  - 開閉状態の永続化を追うときに確認する

### 先に読む upstream docs

- `tree_view-rails` の `README.md`
- `tree_view-rails` の `docs/ja/README.md`
- `tree_view-rails` の `docs/ja/installation.md`
- `tree_view-rails` の `docs/ja/usage.md`
- `tree_view-rails` の `docs/ja/api.md`
- `tree_view-rails` の `docs/ja/decision-guide.md`

### app 側から調べ始める目安

- 文書が表示されない、icon が合わない、開閉状態が崩れる、sidebar の余白や見た目が崩れる場合
- `Document` / `DocumentVersion` / path / 権限制御 / current node 判定が絡む場合
- app の partial / helper / CSS で再現条件が変わる場合

### upstream docs / issue も確認する目安

- `TreeView::RenderState`、`UiConfigBuilder`、`tree_view_rows`、persisted state 自体の使い方が曖昧な場合
- host app responsibility と gem responsibility の境界を見直したい場合
- gem README の導線や導入手順を見直したい場合

### gem 更新後の app-side verification checklist

- `app/helpers/documents_helper.rb` と `app/helpers/projects_helper.rb`
  - folder node、icon、current node、toggle path が現行の tree row 描画と噛み合っているか確認する
- `app/views/documents/_tree.html.erb` と `app/views/projects/_document_detail_tree.html.erb`
  - `tree_view_rows`、toolbar、spacer が desktop / mobile 幅で崩れていないか確認する
- `app/controllers/projects_controller.rb` と `app/models/concerns/tree_view_state_owner.rb`
  - expand / collapse と persisted state が今の render state に追従しているか確認する
- `spec/requests/document_tree_regressions_spec.rb` など公開ツリー導線に近い request spec
  - archived / restore、current document link、tree visibility が回帰していないか確認する
- 切り分け
  - `RenderState`、toolbar helper、公開 API の理解不足なら upstream docs / issue を先に見る
  - icon、label、route、layout だけがずれているなら `docs-portal` 側 issue を優先する

### 関連 issue

- `docs-portal#471` 文書ツリー上のファイルアイコン追従
- `docs-portal#473` 非 Markdown ファイルのツリー表示
- `docs-portal#474` 文書ツリー下端の余白
- `tree_view-rails#384` README の導入経路整理

## rails_table_preferences

### 主な責務

- 一覧の列表示、順序、幅、固定列、filter UI 状態、sort UI 状態、preset 保存の基盤を担います。
- どの table を対象にするか、どの column metadata を出すか、Markdown 由来 HTML にどう適用するかは `docs-portal` 側責務です。

### docs-portal 側の主な確認場所

- `app/controllers/application_controller.rb`
  - `RailsTablePreferences::Controller` の include と `rails_table_preference_settings` の公開を確認する
- `config/routes.rb`
  - `RailsTablePreferences::Engine` の mount を確認する
- `config/initializers/rails_table_preferences.rb`
  - table 名、label 解決順、mount path、editor partial などを確認する
- `app/frontend/entrypoints/application.js`
  - `rails-table-preferences` controller の登録を確認する
- `vite.config.ts`
  - `rails_table_preferences` / `rails_table_preferences/controller` の alias を確認する
- `app/views/layouts/application.html.slim`
  - `stylesheet_link_tag "rails_table_preferences"` を確認する
- `app/helpers/admin/document_sets_helper.rb`
  - `table_preferences_column(...)` を使う現行の table column 定義入口を確認する
- `docs-portal#475`
  - Markdown 由来 table への適用検討では、HTML rewrite で何を足すかの論点整理を先に読む

### 先に読む upstream docs

- `rails_table_preferences` の `README.md`
- `rails_table_preferences` の `docs/quick_start.md`
- `rails_table_preferences` の `docs/resource_tables.md`
- `rails_table_preferences` の `docs/controller_integration.md`
- `rails_table_preferences` の `docs/javascript_entrypoints.md`
- `rails_table_preferences` の `docs/javascript_controller.md`
- `rails_table_preferences` の `docs/filter_metadata.md`

### app 側から調べ始める目安

- mount / helper include / initializer 設定 / stylesheet / Stimulus 登録のどこかが欠けていそうな場合
- app 独自の column 定義、table key、renderer、HTML rewrite、文書ごとの preference key が論点になる場合
- Markdown 由来 HTML table のように、通常の Rails helper を通らない描画経路を扱う場合

### upstream docs / issue も確認する目安

- renderer registry、filter metadata、cell editor metadata の責務分担を確認したい場合
- Vite / `app/frontend` での Stimulus 登録や import path 解決の前提を見直したい場合
- host app がどこまで table UI を持ち、gem がどこまで面倒を見るか判断したい場合

### gem 更新後の app-side verification checklist

- `config/routes.rb`、`app/controllers/application_controller.rb`、`config/initializers/rails_table_preferences.rb`
  - engine mount、helper 公開、table key、label resolution、mount path がずれていないか確認する
- `app/frontend/entrypoints/application.js`、`vite.config.ts`、`app/views/layouts/application.html.slim`
  - Stimulus controller 登録、gem JS alias、stylesheet 読み込みが current main の前提どおりか確認する
- `app/helpers/admin/document_sets_helper.rb`
  - `table_preferences_column(...)` の metadata が対象一覧画面の列構成と合っているか確認する
- `app/views/admin/document_sets/_form.html.slim` と table preference editor を出す一覧画面
  - host form と table preference UI が同居しても操作導線が壊れていないか確認する
- request / system spec の確認方針
  - 既存の管理画面 request spec や対象画面に近い system spec を見て、一覧表示、保存導線、主要 path を固定する
  - 近い spec が見当たらない画面では、gem 更新後の代表導線を 1 本だけでも追加しておく
- 切り分け
  - Vite / Stimulus / metadata docs の曖昧さが原因なら upstream docs / issue を先に見る
  - mount path、table key、partial composition など `docs-portal` 固有の組み込み差分なら app 側 issue を優先する

### 関連 issue

- `docs-portal#475` Markdown 由来の HTML table と table preferences
- `rails_table_preferences#11` Rails Fields Kit renderer 連携の end-to-end docs
- `rails_table_preferences#12` 既存 Stimulus application への登録前提
- `rails_table_preferences#13` Vite / `app/frontend` での import 解決前提

## rails_fields_kit

### 主な責務

- 検索可能 select、tag、autocomplete、Tom Select controller、関連 helper / metadata を担います。
- どの画面でその helper を使うか、どの controller 名で登録するか、Turbo 遷移後に app 側で追加の no-op hook が必要かは `docs-portal` 側で確認します。

### docs-portal 側の主な確認場所

- `app/frontend/entrypoints/application.js`
  - `TomSelectController` の登録を確認する
- `vite.config.ts`
  - `rails_fields_kit` / `rails_fields_kit/tom_select_controller` の alias を確認する
- `config/initializers/rails_fields_kit.rb`
  - controller 名と default param / class 設定を確認する
- `app/frontend/lib/tom_select_fields.js`
  - app 側の旧互換 shim が no-op か、まだ責務が残っていないかを確認する
- `app/views/layouts/application.html.slim`
  - root controller 配置と Turbo 配下の DOM 構造を確認する
- `doc/frontend_interaction_policy.md`
  - Tom Select 初期化責務を gem 側 Stimulus へ寄せる方針を確認する

### 先に読む upstream docs

- `rails_fields_kit` の `README.md`
- `rails_fields_kit` の `doc/setup.md`
- `rails_fields_kit` の `doc/public_api.md`
- `rails_fields_kit` の `doc/field_helpers.md`
- `rails_fields_kit` の `doc/controller_helpers.md`
- `rails_fields_kit` の `doc/table_adapters.md`
- `rails_fields_kit` の `doc/events.md`
- `rails_fields_kit` の `doc/configuration.md`

### app 側から調べ始める目安

- Tom Select が動かない、Turbo 後に再初期化されない、controller 名が合わない、CSS 読み込みや alias 解決が怪しい場合
- app 側に残る互換 hook や独自 JavaScript が責務を曖昧にしていそうな場合
- `rfk_*` helper そのものより、controller registration と bundler 前提が論点のとき

### upstream docs / issue も確認する目安

- Vite / `app/frontend` 向けの導入例や import 解決前提を見直したい場合
- table metadata 連携や public import path の扱いを確認したい場合
- helper / controller helper / events の公開面を再確認したい場合

### gem 更新後の app-side verification checklist

- `app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb`
  - controller 名、alias、default config が current main と食い違っていないか確認する
- `app/frontend/lib/tom_select_fields.js`
  - no-op shim のままか確認し、app 側に再初期化責務が戻っていたら app-side regression として扱う
- `app/views/admin/document_sets/_form.html.slim` など `rfk_*` helper を使う画面
  - Turbo 再訪、selected value、placeholder、search/create 導線が崩れていないか確認する
- request / system spec の確認方針
  - `rfk_*` helper を使う host 画面に近い request / system spec を見て、主要フォーム導線を固定する
  - JS 挙動の差分が出たら、まず対象画面に寄った小さな system spec を足す
- 切り分け
  - import path、controller registration、event contract の説明不足なら upstream docs / issue を先に見る
  - 画面固有の param、DOM、Turbo 導線だけが崩れるなら `docs-portal` 側 issue を優先する

### 関連 issue

- `docs-portal#478` no-op Tom Select 互換フック整理
- `rails_fields_kit#8` Vite / `app/frontend` 向け Stimulus 登録例
- `rails_fields_kit#9` Vite / `app/frontend` での import 解決前提

## 切り分けの目安

- app 側 issue に寄せる
  - `docs-portal` の helper、partial、route、権限制御、table key、source path、HTML rewrite、Turbo Stream 応答が原因のとき
  - gem を正しく組み込めていない、または app 独自 DOM が原因のとき
- upstream docs / issue も確認する
  - public API の読み取りづらさ、導入手順の誤読、Vite alias 前提、Stimulus 登録例の不足が原因のとき
  - app 側の使い方が gem docs の曖昧さに引っぱられているとき
- needs-human で止まる
  - Markdown 由来 HTML table へどこまで `rails_table_preferences` を適用するかのように、app 仕様判断が先に必要なとき
  - docs だけではなく実装方針の選択が必要なとき

## 使い方の最短手順

1. この runbook で対象 gem を決める
2. 共通ファイルを読み、app 側の組み込み位置を確認する
3. 該当 gem の upstream README / setup docs を読む
4. 関連 issue の発見根拠と受け入れ条件を確認する
5. app 側で直す話か、upstream docs を直す話か、仕様判断待ちかを分類する
