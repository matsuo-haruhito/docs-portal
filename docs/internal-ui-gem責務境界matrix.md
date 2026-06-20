# internal UI gem責務境界matrix

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を調査・更新するときに、host app 側と upstream gem 側の責務を混ぜないための比較表です。

正本の読み順は [関連gem連携調査runbook](./関連gem連携調査runbook.md) と [フロントエンド操作の方針](../doc/frontend_interaction_policy.md) です。この文書では新しい public API や target SHA は定義せず、`#607` family の screen-by-screen adoption と `#858` family の pinned ref 更新 train が同じ確認観点を参照できるようにします。

API / ownership の境界はこの matrix、admin UI 上で同じ状態表示 cue がどう見えるかの横断整理は [internal UI gem state cue inventory](./internal-ui-gem-state-cue-inventory.md) を参照してください。state cue inventory は見え方・再利用判断の補助であり、CSS token 名、runtime CSS、upstream public API は決めません。

## 3 gem の責務境界

| gem | docs-portal 内で担当すること | 担当しないこと | 最初に見る docs-portal 側の場所 | representative smoke |
| --- | --- | --- | --- | --- |
| `tree_view` | 文書ツリー / 詳細ツリーの render state、行描画、開閉、persisted state の組み込みを確認する | 文書 query、権限制御、route、icon、業務ラベル、current node 判定を upstream gem 側の責務にしない | `app/helpers/documents_helper.rb`、`app/helpers/projects_helper.rb`、`app/views/documents/_tree.html.erb`、`app/views/projects/_document_detail_tree.html.erb`、`app/models/concerns/tree_view_state_owner.rb` | `spec/requests/document_tree_regressions_spec.rb` で sidebar tree、detail tree、persisted state、window offset のどこを確認したかを残す |
| `rails_table_preferences` | 一覧の column metadata、表示設定 editor、stable column key、filter / preset、mounted engine 保存、未ログイン redirect、owner-scoped preference isolation の host 側組み込みを確認する | 案件・文書固有の pinned 判断、filter label、業務列の意味、docs-portal 固有の認可境界を upstream gem 側へ押し戻さない | `app/helpers/admin/document_sets_helper.rb`、`app/views/admin/document_sets/index.html.slim`、`app/controllers/application_controller.rb`、`spec/requests/admin_document_sets_index_spec.rb`、`spec/requests/admin_document_sets_spec.rb` | `admin/document_sets` の editor / table / filter / preset / mounted engine save / main app login redirect / external user owner-scope isolation のどこを確認したかを残す |
| `rails_fields_kit` | form helper、Tom Select wiring、selected value、preload / remote search、validation rerender 後の再表示を確認する | field 名、collection、業務 validation、保存時の params contract を upstream gem 側で定義しない | `app/views/admin/document_sets/_form.html.slim`、`app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb`、`spec/requests/admin_document_sets_spec.rb` | `admin/document_sets` form の initial load、selected value 保持、placeholder、invalid rerender のどこを確認したかを残す |

## 採用順と検証証跡 matrix

`#607` family の screen-by-screen adoption と `#858` family の pinned ref 更新 train では、次の順で見ると upstream public surface、docs-portal の代表画面、証跡の置き場所を混ぜにくくなります。この表は planning handoff です。新しい実装、target SHA、gem 側 API の確定は各 issue / PR で扱います。

| 優先 | 対象 gem / upstream public surface | docs-portal の代表画面または候補画面 | 先に見る upstream issue / PR | downstream smoke / evidence / rollback note の置き場所 | current 判断 |
| --- | --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit`: package-root `TomSelectController`、`form.rfk_select`、rendered-field contract helpers | `admin/document_sets` form、`admin/documents` の `project_id` canary。次の候補は project / company / user / document / document_version の選択欄 | `rails_fields_kit#500` の packaging gate、`doc/public_api.md`、`doc/setup.md`、`doc/events.md`。helper export や sample app checklist の同期が論点なら upstream issue を先に確認する | `docs/関連gem連携調査runbook.md` の `rails_fields_kit` 採用パターン、`docs/internal-ui-gem-js-resolver-matrix.md`、PR update log。代表 smoke は initial load / selected value / placeholder / invalid rerender | 今すぐ使える代表例あり。remote search endpoint や他 form 横展開は Planner に渡す |
| 2 | `rails_table_preferences`: package-root `RailsTablePreferencesController`、mounted engine、column metadata / stable column key | `admin/document_sets` を代表に、`admin/documents`、`admin/projects`、`admin/users`、`admin/external_folder_sync_sources` など実装済み一覧 | `rails_table_preferences#428` の packaging gate、README、`docs/javascript_entrypoints.md`、`docs/javascript_controller.md`。Markdown preview table への適用判断は docs-portal 側 `#475` family と分ける | `docs/関連gem連携調査runbook.md` の table preference pattern、`docs/internal-ui-gem-packaging-gates.md`、PR update log。代表 smoke は editor / table / filter / preset / mounted engine save / main app login redirect / external owner-scope isolation | 実装済み一覧の確認に使える。`admin/document_sets` の mounted engine save は host app 側の representative smoke として扱い、external user の direct save が admin preference ownership に混ざらないことは docs-portal 側境界として記録する。Markdown preview table への採用可否は人間判断が必要 |
| 3 | `tree_view-rails`: render helper / toolbar / package-root JS manifest / event names | sidebar 文書ツリー、文書詳細 tree、persisted state。JS controller import は current `application.js` では未採用 | `tree_view-rails#825` の packaging / asset gate、README、`docs/ja/installation.md`、`docs/ja/usage.md`、`docs/ja/api.md`、`docs/ja/decision-guide.md` | `docs/関連gem連携調査runbook.md` の tree_view checklist、`docs/internal-ui-gem-visual-evidence-runbook.md`、`spec/requests/document_tree_regressions_spec.rb`。rollback note は `#903` child issue / PR に残す | helper / partial integration は今すぐ確認可能。package-root JS adoption は docs-ahead-of-code にしない |

## 共通化できる確認 wording

- JS import boundary は `package-root import を採用` または `documented direct entrypoint を fallback として参照` のどちらかを issue / PR に 1 行で残します。
- visual evidence は artifact path、desktop 観点、narrow viewport 観点、evidence 種別、未取得の証跡、downstream 影響を 1 セットで残します。
- pinned ref 更新は `gem / from / to / representative smoke / result / rollback target` を child issue または PR に残し、3 gem を同じ branch に混ぜません。
- host app の field 名、column key、route、permission、業務 label、owner-scoped preference isolation は docs-portal 側の正本です。upstream docs には general API と packaging gate だけを求めます。
- state cue を横断で読む場合は [internal UI gem state cue inventory](./internal-ui-gem-state-cue-inventory.md) で `current` / `selected` / `active filter` / `selected item` のような似た cue の意味を確認してから、各 screen issue に戻します。

## 次に Planner / Fixer へ渡す候補

1. `rails_fields_kit` は `admin/document_sets` と `admin/documents` の canary を基準に、次の form 候補を 1 画面ずつ切る。remote search endpoint は別 issue にする。
2. `rails_table_preferences` は実装済み一覧の smoke wording をそろえ、new list adoption と Markdown preview table の人間判断を分ける。mounted engine save を扱うときは、未ログイン redirect と external owner-scope isolation を host app evidence として同じ update log に残す。
3. `tree_view-rails` は sidebar / detail tree / persisted state の representative smoke を先に固定し、JS controller import や raw event 名の採用は upstream manifest 確認後にする。

## docs-portal 側に閉じる変更

- 画面ごとの helper 呼び出し、table metadata、form collection、route context、権限制御、業務ラベルを current code に合わせて直す変更
- request spec で host app の truthfulness、stable column key、field 名、再描画後の表示保持、mounted engine redirect / save boundary を固定する変更
- `admin/document_sets` を代表例に、他 screen へ広げる前の確認順や採用パターンを補う docs 更新
- preview iframe や embedded table のように、current app 側 fallback が正本になっている箇所の境界説明

## upstream gem 側へ押し戻す変更

- documented public export、helper option、controller identifier、event name、installation guide の不足や不整合
- package-root import と direct entrypoint のどちらを案内するかの upstream docs 判断
- `tree_view` の render helper / event、`rails_table_preferences` の engine contract、`rails_fields_kit` の helper option そのものの設計変更
- docs-portal だけで再実装した raw data attribute や ad-hoc JavaScript を upstream public surface として一般化したい場合の判断

## pinned ref 更新 train で残すこと

`#858` family の bump では、3 gem を同じ PR に混ぜません。`1 gem = 1 branch = 1 PR` を基本に、次の 6 点を issue / PR 本文 / review follow-up comment のいずれか 1 箇所へ残します。

- gem 名
- from SHA / tag
- to SHA / tag
- 使った representative smoke
- 確認結果
- rollback target

`#607` family の screen adoption は、revision を動かす train と混ぜず、この matrix の「docs-portal 内で担当すること」と「担当しないこと」を先に見てから個別 screen の docs / spec / UI へ進みます。

## 判断に迷ったとき

- screen adoption なら [関連gem連携調査runbook](./関連gem連携調査runbook.md) の host app 採用パターンを先に読む
- revision を動かすなら同 runbook の release train / verification matrix / update log template を先に読む
- public API や helper behavior の正誤判断が必要なら docs-portal 側で確定せず、upstream issue / PR の確認に戻す
- current code、Issue、既存 docs から判断できない場合は `needs-human` として扱い、docs だけで仕様を作らない
