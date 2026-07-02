# internal UI gem adoption evidence map

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を採用・更新するときに、代表 smoke、upstream evidence、更新 train 上の確認順、rollback note の観点を 1 箇所で確認するための map です。

`#858` の pinned ref update train や `#607` の screen-by-screen adoption では、この表を最初の入口にします。target SHA、known-good revision、人間判断が必要な仕様論点は各 child issue / PR を正本にし、この文書では current `main` から確認できる代表 surface と証跡の置き方だけを扱います。

## 使い方

1. 変更対象の gem を下の map で探す。
2. `docs-portal representative smoke` で host app 側の確認画面・spec を決める。
3. `upstream evidence` で先に見る visual reference / public docs / package guard を確認する。
4. `update train での確認順` に沿って package / wiring / host screen の順に確認する。
5. PR body、issue comment、review follow-up comment のいずれか 1 箇所に `rollback note に残す観点` を記録する。

## Adoption readiness baseline

`#858` の child lane や `#1941` のような横断整理では、次の段階を分けて記録します。CI success、mergeability、merged、docs synced、public surface guard ready を同じ readiness として扱いません。

| 段階 | 採用候補としての読み方 | 記録する最小 evidence |
| --- | --- | --- |
| upstream PR green | upstream 側の候補 PR が CI を通っただけ。docs-portal の target SHA や current support にはしない | upstream PR number、head SHA、CI run、まだ open なら `merge 後に再確認` |
| upstream PR mergeable | conflict がない候補。merge 済み behavior ではないため、docs-portal 側 docs では `確認待ち` として扱う | mergeable true/false、branch freshness、review / human gate の有無 |
| upstream merged | upstream `main` に入った候補。次に package / docs / release guard と docs-portal representative smoke を確認できる | merge commit / upstream docs path / package guard / manifest or public API docs |
| public surface guard ready | package-root export、public API table、manifest、smoke guard のいずれかが merged docs / code で確認できる状態 | source of truth docs、guard spec / verifier、守っている surface、守っていない host app 責務 |
| downstream smoke ready | docs-portal 側の代表画面・request spec・manual evidence・rollback target が揃った状態。ここで初めて bump PR の evidence に使える | screen、from SHA、to SHA、通した smoke、result、rollback target、docs追従要否 |

## Merged upstream boundary notes

`#1755` の docs-only 同期では、上流 gem 側に merge 済みの evidence boundary と、docs-portal 側で残す adoption smoke / rollback note を次のように分けます。ここにある PR は target SHA の指定ではなく、release train で「どの upstream docs を見て、どの downstream smoke を別に残すか」をそろえるための根拠です。

| upstream gem | merged upstream evidence | docs-portal 側に残す downstream evidence | 書かないこと |
| --- | --- | --- | --- |
| `tree_view` | `tree_view-rails#1184` で release docs に downstream host app evidence boundary が追加済み。TreeView 側 evidence は public API manifest、package-root exports、public API / feature docs、mockup README / review gallery、browser smoke、package verification を見る | sidebar tree、detail tree、persisted state、selection、window offset、route / permission / business row action、rollback target | docs-portal 固有 SHA、未merge downstream PR、host app の route / permission を TreeView の release-facing source of truth として固定しない |
| `rails_table_preferences` | `rails_table_preferences#767` で upstream RTP evidence と downstream host-app adoption smoke の違いを production integration checklist に整理済み | table key、stable column key、filter-sort mapping、preset behavior、export boundary、representative screen smoke、mounted engine の未ログイン redirect / owner-scoped save isolation、rollback target | known-good revision、Markdown preview table 採用判断、host app 固有の column label / filter policy、docs-portal の認可境界を upstream current support として書かない |
| `rails_fields_kit` | `rails_fields_kit#820` で downstream adoption evidence を release checklist に追加済み。RFK 側は public API docs、package-root smoke、package contents spec、release-facing docs guard を見る | field params、selected value、placeholder、invalid rerender、authorization / endpoint behavior、representative form smoke、rollback target | endpoint policy、visible feedback copy、host app validation、downstream 固有 SHA を RFK の public contract として書かない |

## Common adoption evidence template

release train、docs-only sync、review follow-up のどれでも、次の形式で upstream evidence と downstream smoke を分けて残します。gem 固有の route、schema、権限、field params、table key、business copy は docs-portal 側 evidence に閉じ、upstream gem の public contract として書きません。

```text
- gem: <tree_view | rails_table_preferences | rails_fields_kit>
- readiness stage:
  - <upstream PR green | upstream PR mergeable | upstream merged | public surface guard ready | downstream smoke ready>
- upstream evidence:
  - PR / issue / commit:
  - public surface source of truth:
  - package / manifest / smoke guard:
  - current support boundary:
- downstream docs-portal evidence:
  - screen / helper / view / spec:
  - from SHA:
  - to SHA:
  - representative smoke:
  - result:
  - rollback target:
  - docs follow-up:
- unresolved gates:
  - <human gate / manual evidence pending / merge after re-check / host app smoke missing>
```

3 gem 共通で、open PR や proposal は `current support` として書きません。target SHA、`Gemfile` / `Gemfile.lock` 更新、3 gem 同時 bump、upstream PR の review / merge 判断は、この template ではなく各 child issue / PR の人間判断に戻します。

## Cross-repo checklist for #4359 type reviews

internal UI gem の package guard / docs signal / visual evidence を横断で見るときは、次の順で evidence を分けます。

| 確認するもの | 記録する evidence | 注意する境界 |
| --- | --- | --- |
| package / import guard | package-root / direct entrypoint / manifest / verifier / docs source-of-truth family | 3 gem 共通の仕組みへ統一せず、RTP / TreeView / RFK それぞれの正本 docs を書く |
| source review / CI | head SHA、workflow run、guard が守った source / docs signal | CI success を browser visual approval や downstream smoke success として読まない |
| visual evidence | desktop / narrow viewport、長い label / table / field / tree state、実ブラウザで確認したかどうか | screenshot 未取得なら limits と follow-up を明記し、merge判断を自動化しない |
| downstream smoke | docs-portal screen、from / to SHA、representative smoke、rollback target | upstream green だけで Gemfile bump 完了や host app adoption 完了にしない |

この checklist は review / handoff comment に入れる最低限の形です。upstream PR の code review、Gemfile bump 実装、3 gem 一括更新、browser screenshot 取得は各 repo / issue の担当 lane に戻します。

## Representative smoke / evidence map

| gem | docs-portal representative smoke | upstream evidence | update train での確認順 | rollback note に残す観点 |
| --- | --- | --- | --- | --- |
| `tree_view` | `app/views/documents/_tree.html.erb`、`app/views/projects/_document_detail_tree.html.erb`、`spec/requests/document_tree_regressions_spec.rb` の sidebar tree / detail tree / persisted state / window offset | `tree_view-rails` の `README.md`、`docs/en/release.md`、`docs/ja/release.md`、`docs/ja/README.md`、`docs/ja/installation.md`、`docs/ja/usage.md`、`docs/ja/api.md`、`docs/ja/decision-guide.md`、`docs/mockups/review-gallery.html` | 1. pinned ref と upstream public API / release evidence / mockup を確認する。2. `DocumentsHelper` / `ProjectsHelper` / tree partial の render state を確認する。3. sidebar tree と detail tree の両方を smoke する。片方だけなら未確認側を明記する。 | from / to SHA、sidebar tree と detail tree のどちらを見たか、persisted state / selection / window offset の確認結果、戻す ref、query / permission / icon / route は docs-portal 側責務であること |
| `rails_table_preferences` | `app/views/admin/document_sets/index.html.slim`、`app/helpers/admin/document_sets_helper.rb`、`spec/requests/admin_document_sets_index_spec.rb` と `spec/requests/admin_document_sets_spec.rb` の editor / stable column key / filter / preset / mounted engine save / 未ログイン redirect / external user owner-scope isolation | `rails_table_preferences` の `README.md`、`docs/index.md`、`docs/javascript_entrypoints.md`、table preference guide family、release checklist、package verification / manual QA docs、visual overview / demo screen generator。`rails_table_preferences#798` は README/docs family + package verifier を source-of-truth family として明文化する planned 方針で、未 merge の manifest / TypeScript declaration / proposal は current support として扱わない | 1. pinned ref と package-root export / direct controller entrypoint / package verifier を確認する。2. `docs/javascript_entrypoints.md` と release checklist が package-root named export、direct controller import、copied controller files をどう分けているか確認する。3. table metadata helper と view の stable column key を確認する。4. editor / table / filter / preset / mounted engine save を smoke する。5. mounted engine context では未ログイン時に main app の login route へ戻ること、external user の direct save が admin user の preference ownership に混ざらないことを host app 側境界として確認する。6. embedded table や Markdown preview table は current main に実装済みか先に確認する。 | from / to SHA、確認した upstream evidence family、確認した table key、stable column key、filter / preset / save / redirect / owner-scope isolation の結果、戻す ref、document set 固有の列名・公開範囲 label と認可境界は host app 側責務であること。`#789` の known-good 判断では upstream evidence と docs-portal smoke を別項目で残す |
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
- docs-portal 側で確認した mounted engine redirect、owner-scoped save isolation、画面別の認可境界は host app evidence として扱い、upstream gem の一般仕様として固定しません。
- current code、Issue、既存 docs から判断できない visual behavior は `needs-human` として扱い、docs-portal 側で仕様を作りません。
- `#858` の child issue では target SHA と CI / smoke 結果を PR body または issue comment に残し、この文書へ target SHA を固定値として追記しません。
