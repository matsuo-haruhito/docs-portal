# internal UI gem adoption evidence map

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を採用・更新するときに、代表 smoke、upstream evidence、更新 train 上の確認順、rollback note の観点を 1 箇所で確認するための map です。

`#858` の pinned ref update train や `#607` の screen-by-screen adoption では、この表を最初の入口にします。target SHA、known-good revision、人間判断が必要な仕様論点は各 child issue / PR を正本にし、この文書では current `main` から確認できる代表 surface と証跡の置き方だけを扱います。

## 使い方

1. 変更対象の gem を下の map で探す。
2. `docs-portal representative smoke` で host app 側の確認画面・spec を決める。
3. `upstream evidence` で先に見る visual reference / public docs / package guard を確認する。
4. `update train での確認順` に沿って package / wiring / host screen の順に確認する。
5. PR body、issue comment、review follow-up comment のいずれか 1 箇所に `rollback note に残す観点` を記録する。

## Representative smoke / evidence map

| gem | docs-portal representative smoke | upstream evidence | update train での確認順 | rollback note に残す観点 |
| --- | --- | --- | --- | --- |
| `tree_view` | `app/views/documents/_tree.html.erb`、`app/views/projects/_document_detail_tree.html.erb`、`spec/requests/document_tree_regressions_spec.rb` の sidebar tree / detail tree / persisted state / window offset | `tree_view-rails` の `README.md`、`docs/ja/README.md`、`docs/ja/installation.md`、`docs/ja/usage.md`、`docs/ja/api.md`、`docs/ja/decision-guide.md`、`docs/mockups/review-gallery.html` | 1. pinned ref と upstream public API / mockup を確認する。2. `DocumentsHelper` / `ProjectsHelper` / tree partial の render state を確認する。3. sidebar tree と detail tree の両方を smoke する。片方だけなら未確認側を明記する。 | from / to SHA、sidebar tree と detail tree のどちらを見たか、persisted state / selection / window offset の確認結果、戻す ref、query / permission / icon / route は docs-portal 側責務であること |
| `rails_table_preferences` | `app/views/admin/document_sets/index.html.slim`、`app/helpers/admin/document_sets_helper.rb`、`spec/requests/admin_document_sets_index_spec.rb` と `spec/requests/admin_document_sets_spec.rb` の editor / stable column key / filter / preset / mounted engine save | `rails_table_preferences` の `README.md`、`docs/index.md`、table preference guide family、package verification / manual QA docs、visual overview / demo screen generator | 1. pinned ref と package-root export / direct entrypoint fallback を確認する。2. table metadata helper と view の stable column key を確認する。3. editor / table / filter / preset / mounted engine save を smoke する。4. embedded table や Markdown preview table は current main に実装済みか先に確認する。 | from / to SHA、確認した table key、stable column key、filter / preset / save の結果、戻す ref、document set 固有の列名・公開範囲 label は host app 側責務であること |
| `rails_fields_kit` | `app/views/admin/document_sets/_form.html.slim`、`app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb`、`app/frontend/lib/tom_select_fields.js`、`spec/requests/admin_document_sets_spec.rb` の initial load / invalid rerender / selected value | `rails_fields_kit` の `README.md`、`doc/setup.md`、`doc/public_api.md`、`doc/field_helpers.md`、`doc/controller_helpers.md`、`doc/table_adapters.md`、`doc/events.md`、`doc/configuration.md`、`doc/visual_references.md`、`doc/visual_reference_index.html`、`doc/final_release_checklist.md` | 1. pinned ref と package-root export / controller import を確認する。2. `application.js` / `vite.config.ts` / initializer / no-op shim の wiring を確認する。3. `admin/document_sets` form の preload、placeholder、selected value、invalid rerender を smoke する。4. remote search を触る場合だけ endpoint と selected value を追加確認する。 | from / to SHA、確認した field、selected value / placeholder / invalid rerender の結果、戻す ref、field name / params / validation は host app 側責務であること |

## 既存 docs との読み分け

- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) は、対象 gem の upstream docs と app 側確認ファイルを調べ始める入口です。
- [internal UI gem public surface guard playbook](./internal-ui-gem-public-surface-guard-playbook.md) は、3 gem の public surface、docs drift guard、package evidence を同じ粒度で比較する入口です。
- [internal UI gem visual evidence gallery](./internal-ui-gem-visual-evidence-gallery.md) は、代表画面別に upstream evidence と downstream evidence を探す入口です。
- [internal UI gem packaging gate runbook](./internal-ui-gem-packaging-gates.md) は、上流 packaging gate と downstream smoke の境界を確認する入口です。
- [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md) は、current queue、old child issue の historical 扱い、bump 実行前の停止条件を確認する入口です。

## 境界

- この文書は runtime code、Gemfile bump、個別画面実装、visual artifact の作り直しを指示しません。
- upstream gem の API、helper option、controller identifier、event name、package-root export の正誤判断は upstream issue / PR に戻します。
- current code、Issue、既存 docs から判断できない visual behavior は `needs-human` として扱い、docs-portal 側で仕様を作りません。
- `#858` の child issue では target SHA と CI / smoke 結果を PR body または issue comment に残し、この文書へ target SHA を固定値として追記しません。
