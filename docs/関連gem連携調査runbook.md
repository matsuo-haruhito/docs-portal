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
- `vite.config.ts` では package root (`rails_table_preferences`, `rails_fields_kit`) と documented direct entrypoint (`rails_table_preferences/controller`, `rails_fields_kit/tom_select_controller`) の両方を alias しています。これは current app が direct entrypoint を常用しているという意味ではなく、upstream docs の Vite 例や copied-controller migration をそのまま検証できるようにするための compatibility lane として残しています。
- direct entrypoint は「package root で欲しい export がまだ公開されていない」「upstream docs がその path を正規の integration path として案内している」「copied controller / custom boot path からの移行途中で current issue scope がそこに閉じている」といった場合だけ選びます。host app 固有の convenience のために undocumented path や gem 内部ファイルへ飛び込むのは避けます。
- `tree_view` は current `docs-portal` では helper / partial integration が先で、`app/frontend/entrypoints/application.js` から直接 controller import をしていません。JavaScript hook が必要になったら、`tree_view/index.js` を public entrypoint として扱い、`TreeViewEventNames`、`TreeViewControllerIdentifiers`、`registerTreeViewControllers(application)` のような documented package-root export から読み始めます。event 名や controller identifier を raw string で写経したり、`app/javascript/tree_view/*` 配下の内部 file path に依存したりしません。
- `rails_table_preferences` は upstream `docs/javascript_entrypoints.md` が `rails_table_preferences/controller` も `rails_table_preferences` package root も両方案内していますが、current `docs-portal` の representative import は package-root named export です。screen issue で controller 登録の説明を書くときは、まず current `application.js` と同じ package-root import を基準にし、direct path は fallback / migration note としてだけ扱います。
- `rails_fields_kit` も upstream README / `doc/public_api.md` が `TomSelectController` の package-root export と direct import の両方を documented surface としています。current `docs-portal` の representative import は package-root named export なので、新しい helper / controller helper / JS helper を downstream docs に出す前に、README か `doc/public_api.md` で public export になっているかを確認します。未着地の upstream PR で提案されている export 名を current main の durable import として先走って書きません。

### 6. representative smoke で確認する最小観点

- `app/frontend/entrypoints/application.js`
  - package-root import が current host app の default として解決しているかを確認する
- `vite.config.ts`
  - package root と documented direct entrypoint の alias が、upstream docs にある import path と矛盾していないかを確認する
- upstream README / public API docs
  - `rails_fields_kit`: `TomSelectController`
  - `rails_table_preferences`: `RailsTablePreferencesController`
  - `tree_view`: `tree_view/index.js`, `TreeViewEventNames`, `TreeViewControllerIdentifiers`, `registerTreeViewControllers(application)`
  - のように、host app が使う import / export 名が documented public surface として見えるかを確認する
- issue / PR の update log
  - 「package-root import を使ったか」「direct entrypoint を使ったか」「その理由が upstream docs 由来か current migration lane 由来か」を 1 行で残す

## `#607` と `#858` をつなぐ最小ルール

- `#607` は、screen-by-screen に internal UI gem を広げるときの host app 側共通パターンを扱う親 queue です。新しい画面 issue では、この runbook の host-app 採用パターンと代表画面を先に読み、個別画面の convenience のために raw string / raw data attribute / ad-hoc helper を増やさないことを優先します。
- `#858` は、3 gem の pinned ref 更新順、representative smoke、rollback note を扱う release-train 親 queue です。revision を動かす話は screen 改修と同じ PR に混ぜず、child issue (`#921` `#903` `#904`) とこの runbook の matrix を正本に切り分けます。
- `#982` はその橋渡しです。screen adoption を進める人も gem bump を進める人も、同じ public surface / representative smoke / rollback note を参照できる状態を維持します。

### rails_fields_kit を広げるとき

- `#607` の host-app pattern は `admin/document_sets` の `form.rfk_select` と `application.js` / `vite.config.ts` / initializer の wiring を baseline にします。
- `#737` は canary form で `error_surface` をどう opt-in するかを扱う issue です。failure copy や stale error clear を決めたいときは、この runbook の wiring / helper 前提を踏まえつつ `#737` の representative form に閉じて進めます。
- `#921` は release-train child です。target SHA、representative smoke、rollback note は child issue / PR へ残し、host-app failure pattern の設計判断は混ぜません。
- downstream では `data-controller`、remote-search payload、selected preload metadata を raw string / raw data attribute / ad-hoc JSON decode で再実装しません。先に upstream README / `doc/public_api.md` で public export や helper option を確認し、package-root helper export で足りないときだけ issue に理由を残して fallback を選びます。

### tree_view を広げるとき

- `#607` の host-app pattern は `app/helpers/documents_helper.rb`、`app/helpers/projects_helper.rb`、2 つの tree partial、`app/models/concerns/tree_view_state_owner.rb` を first read にします。row label、route context、persisted state を app 側責務としてそろえ、upstream の event / hook export は helper や partial から必要になった分だけ使います。
- `#903` は release-train child です。sidebar tree、detail tree、persisted state の representative smoke と rollback note は child issue / PR へ残し、新しい tree seam の screen adoption とは切り分けます。
- JavaScript hook が必要でも raw event 名、controller identifier、gem 内部 file path を直書きしません。まず documented package-root export (`TreeViewEventNames`, `TreeViewControllerIdentifiers`, `registerTreeViewControllers(application)` など) を確認し、host app 側では route / icon / current row 文脈だけを決めます。

### rails_table_preferences を広げるとき

- `#607` の host-app pattern は `admin/document_sets` の helper metadata + editor + table composition を baseline にします。column metadata、pinned decision、filter label、preset 導線を view 直下へ散らさず、helper と `table_key` でまとめます。
- `#904` は release-train child です。representative admin list / embedded table seam / rollback note は child issue / PR へ残し、screen-by-screen migration の convenience patch と同じ PR に混ぜません。
- preview iframe 内 table は current `main` では `app/frontend/controllers/preview_table_resizer_controller.js` の app-side fallback が正本です。通常一覧と同じつもりで data attribute を足し始めたり、embedded table contract を preview fallback へ混ぜたりせず、仕様判断が必要な場合は `#475` を `needs-human` として参照します。
- export payload、hidden column、saved order の smoke は representative admin list で 1 つずつ固定します。画面ごとに ad-hoc helper や one-off preset を増やす前に、既存 helper metadata へ寄せられないかを確認します。

### 新しい issue / PR を切る前の確認順

1. screen adoption が主題なら `#607` とこの runbook の host-app 採用パターンを読む
2. canary や representative form / tree / list の選定が必要なら、関連 child (`#737` `#921` `#903` `#904`) を読む
3. revision を動かす話なら `#858` とこの runbook の verification matrix / update log template を正本にする
4. upstream docs へ依存する public surface 名は README / public API docs で確認し、未着地の PR 提案名を current main の durable contract として書かない

## 現在の解決 revision の見方

`docs-portal` の `Gemfile` は 3 gem を `ref:` 固定で取り込んでいます。更新方針の正本は `Gemfile`、その時点で app が実際に解決している snapshot は `Gemfile.lock` を見るのが最短です。調査や update log では、必要に応じて `Gemfile` の target ref と `Gemfile.lock` の resolved revision を両方控えます。

| gem | 主な責務 | current resolved revision | 最初の確認先 |
| --- | --- | --- | --- |
| `tree_view` | 文書ツリー / 詳細ツリー / persisted expand state | `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` | `docs-portal` の helper / partial と `tree_view-rails` の `docs/ja/*` |
| `rails_table_preferences` | 一覧の列表示 / filter / sort / preset UI | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `config/initializers/rails_table_preferences.rb` と `rails_table_preferences` の README / `docs/*` |
| `rails_fields_kit` | Tom Select 系 field helper / controller / metadata | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `app/frontend/entrypoints/application.js` / `vite.config.ts` と `rails_fields_kit` の `doc/*` |

### current release-train queue の補足

- `rails_fields_kit` の current resolved revision `0c29bb935a1df3e61add860a966a2fc7ea586b1a` は baseline child `#783` の完了後に `Gemfile` / `Gemfile.lock` へ反映済みです。いまは「最初の active bump family」ではなく、host-app canary や後続 form issue の前提 revision として扱います。
- 残る active family は `tree_view` (`#804`) と `rails_table_preferences` (`#904`) が中心です。とくに `rails_table_preferences` は `#789` の known-good revision 判断を gate として読み、human decision の前に broad bump や canary rollout を混ぜません。

### revision が変わったときの最短確認順

1. `Gemfile.lock` で変わった revision を確認する
2. 対応する gem repo の README / docs / 関連 issue・PR を読む
3. この runbook の app-side verification checklist と代表 smoke contract で `docs-portal` 側の seam を点検する
4. upstream docs の不足か、`docs-portal` 固有の組み込み差分か、仕様判断待ちかを切り分ける

### 補足

- `Gemfile` の `ref:` は「次にどの revision を target にするか」の基準、`Gemfile.lock` の revision は「current main が今どの snapshot を解決しているか」の基準として使い分けます
- gem bump の記録では、`Gemfile.lock` の from / to revision を正本にしつつ、必要なら `Gemfile` の target ref や関連 issue / PR も一緒に残します

## release train の最小運用

- この節は `#858` の release train を docs-only で支える子 lane として使います。gem 更新そのものをここで実施するのではなく、「どの revision を見て、どの代表 smoke を通し、どこへ記録するか」を固定するための土台です。
- 3 gem を同じ branch / PR で同時に上げない。`1 gem = 1 branch = 1 PR` を基本とし、他 2 gem は current resolved revision のまま据え置きます。
- bump 前に `Gemfile.lock` の current resolved revision を控え、対応する upstream issue / PR / commit を読んでから target revision を決めます。
- bump 後の記録は `docs-portal` 側の issue か PR 本文に残し、少なくとも `gem 名 / from SHA / to SHA / 実施した代表 smoke / 結果` を書きます。コード上の証跡は `Gemfile.lock` diff を正本として扱います。
- 3 gem すべてに follow-up が必要でも、同一 PR に混ぜず、小さい issue や checklist に分けて順に進めます。
- smoke の失敗原因が `docs-portal` 固有の helper / partial / spec drift なら app 側 issue を切り、public API や導入手順の読みづらさが原因なら upstream docs / issue を先に確認します。

### current queue の読み分け

- `#858` は parent queue です。3 gem 全体の更新順や child slice を見直すときに参照し、実装や docs 更新の最小単位としては扱いません。
- `#804` は current open の `tree_view` baseline bump child です。`#699` でそろえた前回 baseline を完了済み参照として扱い、残る active family の先頭としてここから切り分けます。
- `#904` は current open の `rails_table_preferences` third-slice child です。representative smoke と rollback note の置き場を固定する主 lane として読みます。
- `#789` は `rails_table_preferences` の known-good revision 判断を扱う `status:needs-human` issue です。human decision が入る前に broad bump や downstream canary を混ぜません。
- `#783` は `rails_fields_kit` baseline 更新の完了済み child です。current pinned ref を参照するときの履歴として扱い、次の dependency move が必要でも別 child issue / PR に切り分けます。

### 3 gem 共通 verification matrix

この matrix は `#930` の shared note です。3 gem を同じ粒度で見比べるための source of truth として使い、target SHA の最終判断や bump 実施そのものは各 child issue / PR に残します。

| gem | child lane | current status | current resolved revision | target / gate | representative smoke | upstream review / blocker | rollback target |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rails_fields_kit` | `#921` | `status:needs-human` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | 次の target SHA は未確定。upstream helper-export lane の human review / merge 後に child 側で決める | `admin/document_sets` form の selected 値保持、preload or remote search 1 導線、validation rerender 後の redisplay | human-review-first lane は `rails_fields_kit#273` → `#195` / `#170`。この matrix では merge point を決めない | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` |
| `tree_view` | `#903` | `status:ready-for-agent` | `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` | 次の target SHA は `#903` の update log で child 単位に決める | sidebar tree の expand / collapse、detail tree の route context、persisted state | public hook / selection lane のレビューは upstream 側に残し、downstream では smoke と rollback note に閉じる | `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` |
| `rails_table_preferences` | `#904` | `status:ready-for-agent` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | 次の target SHA は child 単位で決める。known-good revision の human gate は `#789` に残す | `admin/document_sets` の editor / filter / preset、mounted engine save。embedded table を触るときだけ別途 note を足す | `#789` の known-good revision 判断と、preview table fallback (`#475` 系) の仕様論点はここへ混ぜない | `b3f1a9d6eb46aefe568c637396fab63151aef322` |

- `#921` は matrix 追加によって再オープン扱いにしません。current status は `needs-human` のまま読みます。
- `#903` と `#904` は executable child ですが、target SHA と詳細な smoke evidence は各 child issue / PR 本文で残します。
- 実際の bump を書くときは、この matrix を見出しの正本にしつつ、下の update log テンプレートへ from / to SHA と結果を書き足します。

### 代表 smoke の早見表

| gem | current canary surface | 最小の spec / evidence | update log に残す観点 |
| --- | --- | --- | --- |
| `tree_view` | `app/views/documents/_tree.html.erb` と `app/views/projects/_document_detail_tree.html.erb` | `spec/requests/document_tree_regressions_spec.rb` の tree visibility / persisted state / window offset | sidebar tree、detail tree、persisted state のどこを確認したか |
| `rails_table_preferences` | `app/views/admin/document_sets/index.html.slim` の editor + table | `spec/requests/admin_document_sets_index_spec.rb` と `spec/requests/admin_document_sets_spec.rb` の editor / mounted engine 保存 | stable column key、filter/preset、engine save のどこを確認したか |
| `rails_fields_kit` | `app/views/admin/document_sets/_form.html.slim` の `rfk_select` 群 | `spec/requests/admin_document_sets_spec.rb` の initial load / invalid rerender | selected value 保持、placeholder、Turbo 再訪で何を確認したか |

- `rails_table_preferences` と `rails_fields_kit` は同じ `admin/document_sets` surface を share していますが、update log は helper / table metadata と field helper / Tom Select wiring を分けて残します。
- `tree_view` は sidebar tree と detail tree の 2 画面が別 surface なので、片方だけ見た場合は未確認側を明記します。

### update log の残し方

- 記録先は `docs-portal` 側の issue、PR 本文、または review follow-up comment のいずれか 1 つに固定し、同じ更新の履歴を複数箇所へ重複して残しません。
- 最低限、次の 6 点を 1 セットで残します。
  - `gem 名`
  - `from SHA / tag`
  - `to SHA / tag`
  - `使った代表 smoke`
  - `確認結果`
  - `rollback 時に戻す SHA / tag`
- 代表 smoke と確認結果は「通った / 落ちた」だけでなく、どの `docs-portal` 画面や request spec を見たかが分かる粒度で書きます。
- rollback 先は通常 `from SHA / tag` と同じで構いませんが、hotfix や別 branch を挟む場合は実際に戻す revision を明記します。

### update log テンプレート

```text
- gem: rails_fields_kit
- from: 0c29bb935a1df3e61add860a966a2fc7ea586b1a
- to: <target SHA or tag>
- representative smoke:
  - admin/document_sets form の preload / selected value 保持
  - application.js / vite.config.ts / rails_fields_kit initializer の wiring
- result:
  - request spec と画面確認で current contract 維持
  - 追加の follow-up: なし
- rollback target:
  - 0c29bb935a1df3e61add860a966a2fc7ea586b1a
```

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

- `TreeView::RenderState`、toolbar helper、公開 API の理解不足なら upstream docs / issue を先に見る
- icon、label、route、layout だけがずれているなら `docs-portal` 側 issue を優先する

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

### 代表 smoke contract

- サイドバーの文書ツリー (`app/views/documents/_tree.html.erb`)
  - 代表フォルダ 1 つを開閉し、current document link が消えたり別階層へ飛んだりしないことを確認します。
- 文書詳細のツリー (`app/views/projects/_document_detail_tree.html.erb`)
  - 同じ文書 / フォルダ階層が detail 側でも見え、toolbar から expand / collapse を実行できることを確認します。
- persisted state (`app/models/concerns/tree_view_state_owner.rb`)
  - 開いた状態を保存したあと、同じ利用者の再訪や再描画で expand state が戻ることを確認します。
- request spec の裏づけ
  - `spec/requests/document_tree_regressions_spec.rb` に近い既存 spec で、tree visibility や current document 導線が崩れていないことを確認します。

### 関連 issue

- `docs-portal#471` 文書ツリー上のファイルアイコン追従
- `docs-portal#473` 非 Markdown ファイルのツリー表示
- `docs-portal#474` 文書ツリー下端の余白
- `tree_view-rails#384` README の導入経路整理

## rails_table_preferences

### 主な責務

- 一覧の列表示、順序、幅、固定列、filter UI 状態、sort UI 状態、preset 保存の基盤を担います。
- どの table を対象にするか、どの column metadata を出すか、Markdown 由来 HTML にどう適用するかは `docs-portal` 側責務です。

### Markdown preview table の current main contract

- Docusaurus / preview iframe 内の Markdown table は、current `main` では `rails_table_preferences` 未適用です。
- 代わりに `app/frontend/controllers/preview_table_resizer_controller.js` が app 側 fallback path として、表幅、列幅、ヘッダー固定、先頭列固定、localStorage ベースの永続状態を扱います。
- `docs-portal#475` は「Markdown table にどこまで gem を適用するか」の親論点で、`needs-human` のままです。
- `docs-portal#542` と PR `#550` は fallback path の stable key を `document_version:<public_id>:<normalized_site_path>:table:<index>` に寄せた first slice です。
- `docs-portal#547` は、その fallback path が通常表示と embedded 表示で state を共有できることを守る quality queue です。

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
- `app/frontend/controllers/preview_table_resizer_controller.js`
  - Markdown preview table の current fallback path、stable key、localStorage state を確認する
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
- Markdown preview table の幅調整、sticky state、embedded 共有、stable key が論点になる場合

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
- `app/frontend/controllers/preview_table_resizer_controller.js`
  - Markdown preview table に触る issue では、fallback path の key / state / embedded 共有が current main と矛盾していないか確認する
- request / system spec の確認方針
  - 既存の管理画面 request spec や対象画面に近い system spec を見て、一覧表示、保存導線、主要 path を固定する
  - 近い spec が見当たらない画面では、gem 更新後の代表導線を 1 本だけでも追加しておく
- 切り分け
  - Vite / Stimulus / metadata docs の曖昧さが原因なら upstream docs / issue を先に見る
  - mount path、table key、partial composition など `docs-portal` 固有の組み込み差分なら app 側 issue を優先する
  - preview table tool の state や embedded 共有の崩れは app 側 issue を優先する
  - Markdown preview table へ `rails_table_preferences` をどこまで導入するかは `docs-portal#475` の仕様判断なので `needs-human` として扱う

### 代表 smoke contract

- `admin/document_sets` の一覧表示
  - `app/views/admin/document_sets/index.html.slim` で editor と table が同じ `table_key` を共有し、代表列の stable column key が描画されることを確認します。
- filter panel の最小導線
  - 代表列 1 本で filter panel を開き、apply / clear を往復しても host form や一覧描画が崩れないことを確認します。
- preset の保存または読み戻し
  - engine 経由の preset 保存が対象 issue の範囲なら保存から再読込まで確認し、保存を触らない slice でも既存 preset の読み戻しが壊れていないことを確認します。
- Markdown preview table を触る issue の扱い
  - preview iframe 内 table は app 側 fallback path が正本なので、この smoke だけで代替せず `docs-portal#475` `#542` `#547` の論点と分けて扱います。

### 関連 issue

- `docs-portal#475` Markdown 由来の HTML table と table preferences
- `rails_table_preferences#11` Rails Fields Kit renderer 連携の end-to-end docs
- `rails_table_preferences#12` 既存 Stimulus application への登録前提
- `rails_table_preferences#13` Vite / `app/frontend` での import 解決前提
- `rails_table_preferences#20` 既存 HTML table に data 属性を付けて導入する最小例

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

### 代表 smoke contract

- `admin/document_sets/_form.html.slim` の preload 導線
  - 代表 field が initial load で描画され、`allow_clear` と placeholder が current main のまま出ていることを確認します。
- selected value の保持
  - validation error 後または Turbo 再訪後も同じ field 名と selected value が残ることを確認します。
- wiring の健全性
  - `app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb`、`app/frontend/lib/tom_select_fields.js` をまとめて見て、controller registration と no-op shim の責務が戻っていないことを確認します。
- remote search を触る issue の扱い
  - current main の代表 smoke は preload / collection path で足りますが、remote search を変える issue では対象 endpoint と selected value の両方を追加確認します。

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
