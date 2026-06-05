# internal UI gem public surface guard playbook

この文書は、`docs-portal` で `tree_view` / `rails_fields_kit` / `rails_table_preferences` の target SHA や downstream adoption readiness を比較するときに、public surface、docs drift guard、package evidence を同じ粒度で見るための maintainer playbook です。

`#1300` / `#1301` / `#789` のような downstream bump issue では、この文書で upstream readiness の確認観点をそろえ、実際の target SHA、Gemfile / lockfile 更新、host app smoke 結果、rollback target は各 child issue / PR に残します。

## 使うタイミング

- internal UI gem release train (`#858`) の child issue で target SHA を決める前
- upstream の public docs / package entrypoint / verifier が、docs-portal 側の代表 smoke に足りるかを比較したいとき
- review follow-up で「上流の docs / package guard はあるが、host app 側 smoke が未確認」なのか、「上流の public surface 自体が未整理」なのかを切り分けたいとき

## Guard pattern matrix

| upstream gem | public surface の source of truth | docs drift / public docs guard | package / entrypoint evidence | docs-portal adoption readiness で見ること | 不足または人間確認に戻すこと |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | `config/public_api_manifest.yml` が Ruby module methods、public constants、helper methods、toolbar actions、grouped option keys、JavaScript package-root named exports、controller registrations、event names / detail keys を列挙する | `README.md` と `docs/ja/*` / `docs/en/*` / mockups を入口にする。manifest と docs の drift guard がある前提で、release-facing docs は manifest にある current surface だけを書く | built gem に JavaScript / CSS / importmap entrypoint が入る release safety laneを確認する。docs-portal では packaged entrypoint の存在だけで host integration 成功とは扱わない | sidebar tree、detail tree、persisted state、selection、window offset を `docs/internal-ui-gem-adoption-evidence-map.md` の representative smoke に沿って見る | host app の query、route、permission、icon、文書行の business action は tree_view 側の public surface として扱わない。manifest にない open PR / proposal hook は current support として書かない |
| `rails_fields_kit` | `doc/public_api.md` が Ruby entrypoint、configuration、FormBuilder helpers、controller helpers、token suggestions、table metadata adapters、JavaScript exports、Stimulus values / lifecycle / events を説明する | `doc/setup.md`、`doc/field_helpers.md`、`doc/controller_helpers.md`、`doc/table_adapters.md`、`doc/events.md`、`doc/configuration.md`、`doc/visual_references.md`、`doc/final_release_checklist.md` を public docs family として見る。manifest 形式の統一はこの repo から要求しない | `package.json` の `exports` は package root と `./tom_select_controller` を持つ。`check:js` は package exports smoke と Tom Select 周辺の JavaScript checks を含む | `admin/document_sets` form の preload、placeholder、selected value、invalid rerender、`application.js` / `vite.config.ts` / initializer wiring を見る | endpoint behavior、authorization、query parsing、visible feedback copy、retry UI、field name / params / validation は host app 側責務。remote search や token search の新 behavior は merge 済み upstream docs / current app code を確認してから書く |
| `rails_table_preferences` | `README.md` と `docs/index.md` family を入口にし、`docs/javascript_entrypoints.md`、release checklist、package verification を public surface の source-of-truth family として読む。`rails_table_preferences#798` の planned 方針はこの family を明文化する first slice であり、manifest を current support として先取りしない | quick start、production integration checklist、install paths、support matrix、decision guide、troubleshooting、manual QA / release check docs を入口にする。TreeView 型 manifest は helper / JS export / generator surface が増えた場合の将来 option として扱い、current docs では README/docs family と verifier の責務分離を見る | `package.json` の `exports` は package root と `./controller` を持つ。package verifier / release checklist は package-root named export、direct controller import、packaged copied/package controller files の evidence として確認する。TypeScript declaration や manifest drift guard は merge 済みでない限り `確認待ち` として分ける | `admin/document_sets` の editor、stable column key、filter / preset、mounted engine save、export / table preference 境界を代表 smoke として見る。table key、stable column key、filter / sort mapping、preset behavior、rollback target は docs-portal 側 evidence として記録する | table key、列 metadata、検索 filter、export semantics、Markdown preview table fallback は docs-portal 側責務。known-good revision 判断や preview table 採用判断は `#789` / 関連 issue に戻す。`#798` や upstream proposal の結論を docs-portal 側で決めない |

## Review checklist

1. 対象 gem の public surface 正本を 1 つ決める。
2. public docs がその surface を説明しているか、docs drift guard または release checklist の有無を確認する。
3. package-root import、direct entrypoint、`.d.ts`、manifest、package verifier のうち、今回の downstream smoke に必要な evidence がどこまであるかを見る。
4. upstream evidence と docs-portal representative smoke を分けて PR body / issue comment に記録する。
5. open PR、proposal、未 merge docs、未確定 target SHA を release-facing docs に先取りしない。
6. upstream の仕組みを統一する必要が出た場合は、この docs issue で決めず、対象 upstream repo の issue に戻す。

## update log に残す最小項目

```text
- gem: <tree_view | rails_fields_kit | rails_table_preferences>
- public surface checked:
  - <manifest / public_api.md / README + docs index>
- docs drift / release guard checked:
  - <guard name or docs path>
- package evidence checked:
  - <package exports / verifier / .d.ts / built gem gate>
- docs-portal representative smoke:
  - <host app surface / spec / manual evidence>
- readiness result:
  - <ready / needs-human / blocked by upstream / blocked by host app smoke>
- rollback target:
  - <from SHA or tag>
```

## 既存 docs との読み分け

- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md) は、docs-portal 側の代表画面、upstream evidence、確認順、rollback note を見る入口です。
- [internal UI gem packaging gate runbook](./internal-ui-gem-packaging-gates.md) は、上流 packaging gate と downstream smoke の境界を確認する入口です。
- [internal UI gem visual evidence gallery](./internal-ui-gem-visual-evidence-gallery.md) は、代表画面別に visual evidence を探す入口です。
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) は、issue 調査時に先に読む docs-portal / upstream docs の入口です。

## 境界

- この文書は upstream repo の manifest 形式、CI verifier、package export 方針を統一しません。
- この文書は `Gemfile` / `Gemfile.lock`、runtime code、spec、visual artifact を変更しません。
- current code、merged upstream docs、Issue / PR から判断できない target SHA や public API の正誤は `needs-human` として扱います。
- `#858` の全面再編、3 gem 同時 bump、screen-by-screen adoption 実装はこの文書の対象外です。
