# internal UI gem release evidence matrix

この文書は、`docs-portal` が downstream host app として `tree_view-rails` / `rails_table_preferences` / `rails_fields_kit` を採用・更新するときに、upstream 側の evidence entrypoint を同じ粒度で比較するための薄い matrix です。

- release train と current resolved revision の正本は [`関連 gem 連携調査 runbook`](./関連gem連携調査runbook.md) です。
- packaging gate の正本は [`internal UI gem packaging gate runbook`](./internal-ui-gem-packaging-gates.md) です。
- visual artifact / screenshot / mockup evidence の正本は [`internal UI gem visual evidence runbook`](./internal-ui-gem-visual-evidence-runbook.md) と [`internal UI gem visual evidence gallery`](./internal-ui-gem-visual-evidence-gallery.md) です。
- この文書では target SHA を決めません。`#858` の child issue / PR 本文 / review follow-up comment に、old SHA、target SHA、representative smoke、rollback note を残します。

## 使うタイミング

- `#858` の child issue で pinned ref bump の target SHA を決める前
- `#607` 系の screen-by-screen rollout で、対象 gem の public surface / visual evidence / package evidence を確認する前
- upstream gem 側の docs や guard が増えたときに、downstream 採用判断で見る入口をそろえたいとき

この matrix は入口の索引です。upstream docs 形式を `docs-portal` 側で標準化したり、package verification script、public API manifest schema、visual artifact 生成手順を変更したりしません。

## release evidence matrix

| gem | package-root / direct entrypoint の source of truth | public API / event surface の drift guard | visual reference / mockup / screenshot evidence | package verification / release checklist | downstream smoke で見る代表 screen | ref bump 時の記録先 |
| --- | --- | --- | --- | --- | --- | --- |
| `tree_view-rails` | upstream `README.md`、`docs/ja/installation.md`、`docs/ja/usage.md`、`docs/ja/api.md`。`docs-portal` では `docs/internal-ui-gem-js-resolver-matrix.md` と `app/frontend/entrypoints/application.js` で package-root / direct entrypoint の使い分けを確認する。 | upstream `docs/ja/api.md`、`docs/ja/decision-guide.md`、public export (`TreeViewEventNames`、`TreeViewControllerIdentifiers`、`registerTreeViewControllers(application)`) の docs / guard。raw event 名や controller identifier を host app に直書きしない。 | upstream mockup gallery、persisted state guide 用 HTML / CSS、`docs/internal-ui-gem-visual-evidence-runbook.md` の `tree_view-rails` 行。 | `docs/internal-ui-gem-packaging-gates.md` の `tree_view-rails#825` 行。built gem に JavaScript / CSS / importmap entrypoint が入ることを確認する gate を見る。 | `app/views/documents/_tree.html.erb`、`app/views/projects/_document_detail_tree.html.erb`、`spec/requests/document_tree_regressions_spec.rb`。sidebar tree、detail tree、persisted state を分けて記録する。 | `#903` 系 child issue / PR update log。from / to SHA、sidebar tree / detail tree / persisted state の確認結果、rollback target を 1 セットで残す。 |
| `rails_table_preferences` | upstream `README.md`、docs index、JavaScript entrypoint docs。`docs-portal` では `docs/internal-ui-gem-js-resolver-matrix.md`、`app/frontend/entrypoints/application.js`、`vite.config.ts` で `rails_table_preferences` / `rails_table_preferences/controller` の扱いを確認する。 | upstream public API / JavaScript entrypoint guard、package-root export drift guard (`rails_table_preferences#678`)。column metadata や table key は `docs-portal` の helper 側責務として分ける。 | upstream visual overview、generated demo、editor / table mockup、`docs/internal-ui-gem-visual-evidence-runbook.md` の `rails_table_preferences` 行。 | `docs/internal-ui-gem-packaging-gates.md` の `rails_table_preferences#428` 行。built gem の `package.json` exports と package-root / direct controller entrypoints を確認する gate を見る。 | `app/views/admin/document_sets/index.html.slim`、`spec/requests/admin_document_sets_index_spec.rb`、`spec/requests/admin_document_sets_spec.rb`。editor、filter / preset、mounted engine save、stable column key を確認する。embedded table は必要時だけ別 note に分ける。 | `#904` 系 child issue / PR update log。from / to SHA、admin/document_sets smoke、engine save、rollback target を残す。known-good revision の human gate (`#789`) とは混ぜない。 |
| `rails_fields_kit` | upstream `README.md`、`doc/setup.md`、`doc/public_api.md`、`doc/field_helpers.md`、`doc/controller_helpers.md`。`docs-portal` では `app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb` で package-root / Tom Select direct entrypoint を確認する。 | upstream public API docs、helper / controller helper docs、events docs、package export guard。`TomSelectController`、`rfk_*` helper、event contract を current upstream docs で確認する。 | upstream `doc/*_visual_reference.html`、focused field HTML、`docs/internal-ui-gem-visual-evidence-runbook.md` の `rails_fields_kit` 行。 | `docs/internal-ui-gem-packaging-gates.md` の `rails_fields_kit#500` 行。built `.gem` artifact から packaged `package.json` exports と target files を確認する gate を見る。 | `app/views/admin/document_sets/_form.html.slim`、`spec/requests/admin_document_sets_spec.rb`、`app/frontend/lib/tom_select_fields.js`。selected value、placeholder、validation rerender、Turbo 再訪、no-op shim を確認する。 | `#921` / `#991` 系 child issue / PR update log。from / to SHA、admin/document_sets form smoke、wiring、rollback target を残す。host form redesign や failure pattern 設計とは混ぜない。 |

## release train / screen rollout からの読み方

1. `#858` の pinned ref bump が主題なら、まず [`関連 gem 連携調査 runbook`](./関連gem連携調査runbook.md) で current resolved revision と child lane を確認します。
2. この matrix で対象 gem の upstream docs / guard / visual evidence / package gate の入口を確認します。
3. target SHA は child issue / PR で決め、update log に from / to SHA、representative smoke、result、rollback target を残します。
4. `#607` 系の screen rollout が主題なら、対象 screen の host-app pattern を先に確認し、upstream public surface と visual reference は採用根拠として参照します。
5. upstream gate の成功だけで downstream integration 成功とは扱いません。`docs-portal` 側の representative smoke と、route / helper / partial / CSS / permission の確認を別に残します。

## update log に残す最小セット

```text
- gem: <tree_view-rails | rails_table_preferences | rails_fields_kit>
- evidence matrix checked:
  - docs/internal-ui-gem-release-evidence-matrix.md
- package / entrypoint source:
  - <upstream README / public API / package gate issue>
- visual evidence source:
  - <upstream visual reference / mockup / docs-portal visual evidence runbook>
- from: <Gemfile.lock current SHA or tag>
- to: <target SHA or tag>
- representative smoke:
  - <docs-portal screen / request spec / system spec>
- result:
  - <confirmed behavior and any follow-up>
- rollback target:
  - <SHA or tag to restore>
```

## 非目標

- `Gemfile` / `Gemfile.lock` の更新
- upstream gem 側 docs の構造統一
- package verification script や manifest schema の変更
- visual reference artifact の新規生成
- `#607` の screen-by-screen rollout 実装
- `#858` の target SHA 判断
- human gate (`#789` など) の代替
