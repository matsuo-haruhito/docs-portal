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
- `docs/internal-ui-gem-js-resolver-matrix.md`
  - 3 gem の package-root import / direct entrypoint / Vite resolver 境界を同じ粒度で確認する

## docs-portal での host app 側採用パターン

この repo で `rails_fields_kit` と `rails_table_preferences` を広げるときは、まず `admin/document_sets` を current main の代表例として読みます。`#587` `#588` `#593` `#594` `#597` のような screen-by-screen issue を進めるときも、この代表例から外れる理由があるかを先に確認すると、helper 呼び出し、一覧構成、spec 粒度がぶれにくくなります。

### 1. `collection_select` を `rfk_select` へ寄せるとき

- `app/views/admin/document_sets/_form.html.slim` のように、host app 側では `form.rfk_select` を使い、`collection`、`collection_value_method`、`collection_label_method` を明示します。
- blank を許容する項目では `allow_clear: true` と `placeholder` をセットにし、`project_id` のような既存 params 名は変えません。
- wrapper や label は helper 側ではなく呼び出し側 view で揃え、この repo の form grid に沿わせます。
- Turbo 再訪や validation error 後も同じ field 名で再描画されることを優先し、画面ごとの独自 JavaScript を先に足しません。
- まず `app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb` の wiring が current main で有効かを確認し、そのうえで個別画面へ広げます。

### 2. `rails_table_preferences` を使う一覧の組み方

- `app/views/admin/document_sets/index.html.slim` のように、ページ先頭で `table_key`、`table_columns`、`table_settings` を定義してから view を組みます。
- 列 metadata は `app/helpers/admin/document_sets_helper.rb` のような helper に寄せ、view 側へ column 幅、pinned、filter、label の判断を散らさないようにします。
- host form と一覧が同居する画面では、`新規登録` card と `表示設定` editor、その下の table を役割ごとに分け、editor と table は同じ `table_key` を共有します。
- 一覧本体は `table_preferences_table_tag(...)` を使い、`thead` と `tbody` の各 cell に stable な `data-rails-table-preferences-column-key` を置きます。
- `project` や `actions` のように一覧の文脈維持に効く列は helper 側で pinned を決め、host app の運用都合を upstream gem へ押し戻しません。

### 3. spec をどの粒度で置くか

- request spec では、`spec/requests/admin_document_sets_spec.rb` のように `rfk_select` 化した field 名が initial load と invalid rerender の両方で残ることを確認します。
- 一覧を `rails_table_preferences` 化した画面では、request spec で editor が描画されること、stable column key がそろうこと、必要なら mounted engine API を通じた設定保存まで 1 本で確認します。
- `spec/requests/admin_document_sets_index_spec.rb` のように、代表 row の cell と action path を DOM ベースで押さえておくと、列 metadata の drift を検知しやすくなります。
- source spec は every screen に機械的に増やすのではなく、helper 抽出や entrypoint wiring のように markup / source 契約そのものを守りたい場面へ絞ります。
- まず request spec で host 画面の truthfulness を守り、JavaScript や helper seam の回帰を別に固定したいときだけ source spec を追加します。

### 4. 変更前に見る最小セット

1. `app/views/admin/document_sets/_form.html.slim`
2. `app/views/admin/document_sets/index.html.slim`
3. `app/helpers/admin/document_sets_helper.rb`
4. `spec/requests/admin_document_sets_spec.rb`
5. `spec/requests/admin_document_sets_index_spec.rb`
6. `app/frontend/entrypoints/application.js`
7. `vite.config.ts`
8. `config/initializers/rails_fields_kit.rb`
9. `config/initializers/rails_table_preferences.rb`

この順で見ると、form helper、table metadata、entrypoint wiring、回帰確認の責務分担を current main から短時間で把握できます。

### 5. package-root import / direct entrypoint の使い分け

- `docs-portal` の current `app/frontend/entrypoints/application.js` は `import { RailsTablePreferencesController } from "rails_table_preferences"` と `import { TomSelectController } from "rails_fields_kit"` を使っています。current main の host-app default は、このように upstream README / public API が stable export として案内している package root を先に使う形です。
- `vite.config.ts` では package root (`rails_table_preferences`, `rails_fields_kit`) と documented direct entrypoint (`rails_table_preferences/controller`, `rails_fields_kit/tom_select_controller`) の両方を alias しています。これは current app が direct entrypoint を常用しているという意味ではなく、upstream docs の Vite 例や copied-controller migration をそのまま検証できるようにしているものです。
- 3 gem 横断の早見表は `docs/internal-ui-gem-js-resolver-matrix.md` を確認します。

以降の個別 gem ごとの確認観点は、この package-root / direct entrypoint の境界を崩さない前提で読みます。
