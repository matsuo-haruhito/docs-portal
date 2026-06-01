# internal UI gem public surface / package verification matrix

この文書は、`tree_view` / `rails_table_preferences` / `rails_fields_kit` の public surface、package verification、TypeScript declaration、public API manifest の境界を、`docs-portal` から同じ粒度で確認するための横断 matrix です。

`docs/internal-ui-gem-js-resolver-matrix.md` は package-root import / direct entrypoint / Vite resolver の実行時解決境界を扱います。この文書は packaging と adopter-visible contract の責務分担を扱い、dependency bump、upstream 実装、manifest schema、CI workflow は変更しません。

## この matrix の使い方

- `Gemfile` の pinned ref を更新する issue では、ここを見て downstream が durable contract として参照してよい artifact を確認します。
- upstream repo の package policy を docs-portal 側で決定せず、current docs / manifest / package verification signal を採用判断の材料として分離します。
- issue / PR 本文では、対象 gem の package-root export、direct entrypoint、TypeScript declaration、manifest、package verification のどれを根拠にしたかを 1 行で残します。
- 未着地の upstream PR や検討中 issue は、current main の durable contract として扱わず、関連 signal として明記します。

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
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | current `application.js` では controller import / register 未採用。helper / partial integration と sidebar / detail tree smoke が中心 | `#858` / `#903` 系の release train child issue |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `RailsTablePreferencesController` を package root から import し、`rails-table-preferences` として register | `#858` / `#904` 系の release train child issue |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `TomSelectController` を package root から import し、`rails-fields-kit--tom-select` として register | `#858` / `#921` 系の release train child issue |

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

- `#1500`: release train current snapshot
- `#858`: internal UI gem pinned ref 更新 train
- `#607`: 管理画面の internal UI gem 展開共通パターン
- `#1470`: internal UI gem state cue inventory
- `tree_view-rails#981`: `config/public_api_manifest.yml` の配布境界と package verification 対象の整理
- `rails_table_preferences#540`: package entrypoint の TypeScript declaration 同梱 signal

この matrix は、3 gem の package policy を docs-portal 側で最終決定する場ではありません。target SHA、representative smoke、rollback target は各 child issue / PR の update log に残し、upstream 実装や package verifier の変更は各 upstream repo の issue / PR へ切り分けます。
