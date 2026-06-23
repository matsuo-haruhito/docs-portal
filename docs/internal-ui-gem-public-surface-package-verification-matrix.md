# internal UI gem public surface / package verification matrix

この文書は、`tree_view` / `rails_table_preferences` / `rails_fields_kit` の public surface、package verification、TypeScript declaration、public API manifest の境界を、`docs-portal` から同じ粒度で確認するための横断 matrix です。

`docs/internal-ui-gem-js-resolver-matrix.md` は package-root import / direct entrypoint / Vite resolver の実行時解決境界を扱います。この文書は packaging と adopter-visible contract の責務分担を扱い、dependency bump、upstream 実装、manifest schema、CI workflow は変更しません。

## この matrix の使い方

- `Gemfile` の pinned ref を更新する issue では、ここを見て downstream が durable contract として参照してよい artifact を確認します。
- upstream repo の package policy を docs-portal 側で決定せず、current docs / manifest / package verification signal を採用判断の材料として分離します。
- issue / PR 本文では、対象 gem の package-root export、direct entrypoint、TypeScript declaration、manifest、package verification のどれを根拠にしたかを 1 行で残します。
- 未着地の upstream PR や検討中 issue は、current main の durable contract として扱わず、関連 signal として明記します。

## public surface 追加時の共通 checklist

3 gem の public surface / package verification を見るときは、repo ごとの checker 実装を揃える前に、次の順で evidence を分けます。ここでの checklist は `docs-portal` の採用判断を揃えるためのもので、upstream repo の manifest schema、package verifier、release policy をこの repo で決めるものではありません。

1. runtime behavior change
   - その PR / issue が実行時挙動を変えるのか、read-only helper / docs signal / package guard だけなのかを先に分けます。
   - runtime behavior が変わる場合は、対象 repo の spec / smoke / visual evidence を正本にし、docs-portal 側では current pin に入るまで current support として書きません。
2. read-only contract
   - rendered field reader、controller identifier reader、manifest reader のような read-only API は、host app の状態を変更しない確認 helper として扱います。
   - helper 名、戻り値 shape、fallback option は upstream public docs / merged code を正本にし、docs-portal 側で名称を先取りしません。
3. docs signal
   - README は exhaustive inventory にせず、public API docs、entrypoint docs、release guide、package verification docs のどれが source-of-truth family かを確認します。
   - docs drift guard がある場合も、guard が守る対象が docs map / release note / setup note / package boundary のどれかを PR body に残します。
4. declaration / manifest / package contents guard
   - TypeScript declaration、public API manifest、package contents verifier は、それぞれ adopter-visible contract を支える補助 evidence として読みます。
   - `tree_view-rails` は public API manifest を強く使い、`rails_table_preferences` は entrypoint docs / package verifier family、`rails_fields_kit` は public API docs / generated setup note / package contents guard を主に見る、という repo 固有の強みを維持します。
5. downstream smoke
   - upstream CI / package guard が green でも、docs-portal の representative smoke にはなりません。
   - release train / bump PR では、from SHA、to SHA、確認した docs-portal 画面または spec、rollback target を別 evidence として残します。
6. visual evidence / release train boundary
   - browser-capable visual evidence は、static artifact / UI cue / layout readability を判断する queue です。
   - release train は Gemfile / Gemfile.lock の pinned ref、representative smoke、rollback note を扱う queue です。visual evidence が green でも、bump 採用や merge 判断の代替にはしません。

### 共通 evidence format

public surface / package verification を根拠にした issue / PR comment では、次の粒度で残します。該当しない項目は `not applicable` とし、未 merge signal は `pending upstream` として current support から外します。

```text
- target gem: <rails_fields_kit | tree_view | rails_table_preferences>
- surface type:
  - <runtime behavior | read-only helper | docs signal | TypeScript declaration | public API manifest | package contents guard | release evidence>
- upstream source of truth:
  - docs / manifest / verifier:
  - PR / issue / commit:
  - status: <merged | open | pending human | historical>
- package verification boundary:
  - guards:
  - does not guard:
- docs-portal downstream evidence:
  - current pin:
  - adoption surface:
  - representative smoke:
  - rollback target:
- next queue:
  - <upstream review | docs-portal release train | visual evidence batch | no downstream action>
```

## 先に見る正本

- `Gemfile`: docs-portal が取り込んでいる 3 gem の pinned ref
- `app/frontend/entrypoints/application.js`: downstream が current main で実際に register している Stimulus controller
- `vite.config.ts`: downstream が解決している package root / documented direct entrypoint alias
- `docs/internal-ui-gem-js-resolver-matrix.md`: import / resolver 境界の正本
- `docs/関連gem連携調査runbook.md`: host app 採用パターン、release train、representative smoke の入口
- upstream docs / manifest / package guard:
  - `tree_view-rails`: `README.md`、`docs/ja/*`、`config/public_api_manifest.yml`、package verification 関連 spec / CI
  - `rails_table_preferences`: `README.md`、`docs/javascript_entrypoints.md`、`docs/javascript_controller.md`、package verification 関連 spec / CI
  - `rails_fields_kit`: `README.md`、`doc/public_api.md`、`doc/setup.md`、`doc/events.md`、package verification 関連 spec / CI

## Current downstream pins

| gem | current docs-portal ref | downstream current adoption | update lane |
| --- | --- | --- | --- |
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | current `application.js` では controller import / register 未採用。helper / partial integration と sidebar / detail tree smoke が中心 | `#858` parent / `#1301` release train child |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `RailsTablePreferencesController` を package root から import し、`rails-table-preferences` として register | `#858` parent / `#789` known-good revision human gate 後に扱う lane |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `TomSelectController` を package root から import し、`rails-fields-kit--tom-select` として register | `#858` parent / `#1300` release train child |

## Public surface / verification boundary

| gem | package-root public export | documented direct entrypoint | TypeScript declaration | public API manifest | package verification / CI boundary | docs-portal durable contract |
| --- | --- | --- | --- | --- | --- | --- |
| `tree_view` | `config/public_api_manifest.yml` の `javascript_package_root.named_exports` が `registerTreeViewControllers`、`TreeViewControllerIdentifiers`、`TreeViewEventNames`、各 controller export を管理する | package-root を入口に扱う。gem 内部の `app/javascript/tree_view/*` path は downstream docs の durable import として書かない | current downstream では TypeScript declaration を adoption gate にしない。型定義が upstream で追加されても、docs-portal の smoke / rollback note とは別に扱う | adopter-visible contract 候補だが、manifest の配布境界や package verification 対象は upstream issue `tree_view-rails#981` の判断に従う | package-root export と manifest / docs の drift を upstream package-sensitive guard で見る。docs-portal 側で verifier policy を再定義しない | sidebar tree、detail tree、persisted state、route context の代表 smoke。JS public hook 採用は current downstream で先取りしない |
| `rails_table_preferences` | `docs/javascript_entrypoints.md` が package root named export `RailsTablePreferencesController` を案内し、docs-portal current import も package root | `rails_table_preferences/controller` は documented fallback / migration lane。通常の screen adoption では package root を優先する | package entrypoint の `.d.ts` 同梱は upstream packaging signal。`rails_table_preferences#540` のような PR が merge されるまでは docs-portal の required contract にしない | current docs-portal adoption では manifest を正本にしない。documented entrypoint docs と package verification signalを優先する | gemspec / package contents / entrypoint docs / type declaration の drift を upstream で確認する。docs-portal CI 判定へ package policy を持ち込まない | `admin/document_sets` の editor、stable column key、mounted engine save、filter / preset smoke |
| `rails_fields_kit` | `doc/public_api.md` が package root named export `TomSelectController` と rendered-field contract helpers を案内する | `rails_fields_kit/tom_select_controller` は documented fallback。new helper / controller helper は README または `doc/public_api.md` で public export か確認する | 型定義は upstream package-root / setup-note follow-up の結果に従う。未着地の declaration 名を downstream durable contract として書かない | current docs-portal adoption では manifest を正本にしない。public API docs と generated setup note / package contents guard を確認する | package-root export、generated setup note、package contents guard の drift を upstream で確認する。docs-portal 側では field helper の request spec と representative smoke に閉じる | `admin/document_sets` form の selected value 保持、placeholder、invalid rerender、Tom Select wiring smoke |

## 責務を混同しないための判断メモ

| 判断対象 | docs-portal で参照してよいもの | docs-portal で決めないもの |
| --- | --- | --- |
| package-root import を採用するか | current `application.js`、`vite.config.ts`、upstream README / public API docs、`docs/internal-ui-gem-js-resolver-matrix.md` | upstream package-root export の命名変更や互換 policy |
| direct entrypoint を文書化するか | upstream が documented fallback として案内している path、migration note | gem 内部 path を durable public path として勝手に昇格すること |
| TypeScript declaration を gate にするか | merge 済み upstream docs / package contents / CI result | 未 merge の declaration PR を docs-portal update の必須条件にすること |
| public API manifest を採用判断に使うか | upstream が adopter-visible artifact として扱うと決めた manifest | manifest schema や配布境界の再設計 |
| package verification をどう読むか | upstream package contents / gemspec / CI package-sensitive 判定の結果 | docs-portal 側で upstream verifier の責務を肩代わりすること |
| release train smoke をどう残すか | issue / PR body の from / to SHA、representative smoke、rollback target | package policy の最終判断や broad dependency bump |

## 最新 upstream signal の読み分け

2026-06-02 JST 時点の関連 issue / PR signal は、current durable contract と未確定 signal を分けて読む。

| signal | matrix での読み方 | 先取りしないこと |
| --- | --- | --- |
| `rails_table_preferences#678` | current main には既に `spec/javascript/rails_table_preferences_entrypoint_spec.rb` があり、package-root named export と direct controller entrypoint の一致は already satisfied / disposition needed として扱う | 重複する smoke や manifest を docs-portal 側の採用条件として追加しない |
| `tree_view-rails#1092` | event detail keys を package-root public export にするかの feature proposal。`status:needs-human` / `risk:medium` の上流判断待ち signal として扱う | `TreeViewEventDetailKeys` のような未確定 export 名や object shape を durable contract として書かない |
| `rails_fields_kit#745` | ROADMAP と public docs の current surface を同期する docs signal。RFK 側の docs が着地した後に public API docs を確認する入口として扱う | docs-portal 側で RFK の新しい public API、helper 名、ROADMAP 方針を確定しない |
| `#858` | internal UI gem pinned ref 更新 train の parent / hub。target SHA、representative smoke、rollback target は child issue / PR に残す | release train 全体をこの matrix で実装・完了扱いにしない |
| `#1470` | state cue inventory の parallel design lane。public surface / package verification とは別の design inventory として読む | dependency bump、package export、runtime adoption の根拠にしない |
| `#607` | host app adoption pattern の整理。screen ごとの採用・smoke の書き方を確認する入口 | upstream package policy や package verification schema を決める場所にしない |

## Issue / PR に残す 1 行メモ

package-root export を根拠にした場合:

```text
- Public surface boundary: package-root public export を採用。根拠は upstream public API docs と docs-portal current application.js。
```

documented direct entrypoint を fallback として参照した場合:

```text
- Public surface boundary: documented direct entrypoint は fallback として参照。package-root import を current downstream default として維持。
```

manifest / package verification を確認材料にした場合:

```text
- Package verification boundary: upstream manifest / package contents guard は採用判断の確認材料として参照。docs-portal 側では verifier policy や manifest schema を変更しない。
```

TypeScript declaration が関連する場合:

```text
- Type declaration boundary: merge 済み upstream package contents に含まれる型定義だけを確認材料にし、未着地 PR の declaration 名は durable contract として書かない。
```

## 関連 issue / signal

- `#1509`: この matrix の追加元で、完了済みの public surface / package verification 整理
- `#858`: internal UI gem pinned ref 更新 train の parent / hub
- `#1300`: `rails_fields_kit` release train child
- `#1301`: `tree_view` release train child
- `#789`: `rails_table_preferences` known-good revision の human gate
- `#607`: 管理画面の internal UI gem 展開共通パターン
- `#1470`: internal UI gem state cue inventory。dependency bump とは別の parallel design lane
- `#3655`: 3 gem 共通の public surface / package verification / release evidence checklist 整理
- `tree_view-rails#981`: `config/public_api_manifest.yml` の配布境界と package verification 対象の整理
- `tree_view-rails#1092`: event detail keys の package-root public export 化を検討する feature proposal。current durable contract ではない
- `rails_table_preferences#540`: package entrypoint の TypeScript declaration 同梱 signal
- `rails_table_preferences#678`: package-root JavaScript export guard の追加候補だったが、current main では already satisfied / disposition needed として扱う
- `rails_fields_kit#745`: ROADMAP / public docs の current surface 同期 signal。docs-portal 側で RFK public API を先取りしない

この matrix は、3 gem の package policy を docs-portal 側で最終決定する場ではありません。target SHA、representative smoke、rollback target は各 child issue / PR の update log に残し、upstream 実装や package verifier の変更は各 upstream repo の issue / PR へ切り分けます。
