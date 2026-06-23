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

## Evidence lane decision matrix

4 repo 横断 issue では、同じ surface を複数の evidence family で重複して守りたくなります。最初に次の lane を 1 つ主軸として選び、足りない証跡だけを補助 lane として PR body / issue comment に残します。CI success、mergeable、merged、downstream smoke ready は別の状態として扱い、open PR や proposal を current support にしません。

| 主軸 lane | 向いている surface | 代表 evidence | docs-portal 側の使い方 | 止める条件 |
| --- | --- | --- | --- | --- |
| `manifest-backed contract` | helper method、option key、event name / detail key、JS export など、複数 docs / tests / downstream smoke にまたがり、drift が互換性リスクになる public surface | upstream manifest、compatibility spec、docs drift guard、package entrypoint smoke | `tree_view` 型の evidence として読む。ほかの gem に同じ形式を要求するのではなく、surface が増えて docs family だけでは守りにくい場合の昇格候補にする | manifest schema、public surface の採否、breaking change 判断が必要な場合 |
| `docs-only sync` | README、public API docs、release checklist、Product Profile、runbook の説明 drift | merged upstream docs、current app docs、closed PR / issue の明示記述 | current behavior の導線や責務境界を更新する。runtime code、Gemfile、CI workflow、upstream docs は触らない | 未merge PR を実装済みとして書く必要がある場合 |
| `package verifier guard` | package-root import、direct entrypoint、built gem / npm artifact に含まれる files、copied controller files | package verifier、built artifact check、`package.json` exports、release checklist | downstream bump 前の upstream gate として見る。host app の selected value、route、permission、table key の成功までは代替しない | package policy や verifier 統一を docs-portal 側で決める必要がある場合 |
| `sample app / downstream smoke` | host app の screen、form、table、tree、selected value、invalid rerender、mounted engine save | sample app evidence、docs-portal request spec、manual smoke、rollback note | `docs-portal` 固有の representative smoke として、from / to SHA、screen、result、rollback target を残す | target SHA、known-good revision、runner-capable manual evidence が未確定の場合 |
| `visual reference evidence` | layout、state cue、interactive affordance、static artifact、mockup と actual UI のズレ | visual reference gallery、mockup browser smoke、screenshot / artifact path | visual artifact 変更や UI cue drift の補助 evidence として使う。current support の正本は code / merged docs / representative smoke に戻す | 画像だけで仕様判断や accessibility / responsive acceptance を決める必要がある場合 |

## Shared observation wording

共通化してよいのは、PR body、Issue comment、release checklist で使う観測語彙と最小 comment 形式までです。repo ごとの script、manifest、package verifier、CI workflow を docs-portal 側から統一実装しません。

共通語彙として使うもの:

- `workflow run`: workflow 名、run number、head SHA、status / conclusion をセットで書く。combined status が空でも、workflow run が exact head に紐づくなら CI evidence として扱える。
- `PR head SHA`: PR body や過去コメントの SHA と、最新 PR metadata の `head_sha` を混同しない。follow-up commit 後は古い green run を current-head evidence として使わない。
- `compare freshness`: `ahead_by` / `behind_by` / `status` は branch freshness の観測であり、`mergeable:true` や CI success の代替ではない。`status:diverged` でも PR metadata が mergeable なら conflict とは分けて読む。
- `skipped job`: changed-files routing や docs-only PR で job が skipped の場合、skipped した理由と、代わりに見た source-level policy / docs-quality / focused spec を分けて書く。
- `CI policy signal`: `permissions: contents: read` のような CI policy guard は、policy wording の再利用候補として読む。required check、branch protection、workflow topology の変更判断は対象 repo の Issue に戻す。
- `visual evidence`: browser screenshot、mockup、gallery、Playwright smoke は layout/readability の証跡であり、CI green や source review の代替ではない。visual evidence が acceptance に含まれる場合は `#3623` / review queue に戻す。

書き分けの最小形:

```text
- workflow run: <name> #<number> on <head SHA> => <status/conclusion>
- compare freshness: ahead_by=<n>, behind_by=<n>, status=<ahead|behind|diverged|identical>
- skipped jobs: <job names and why they were skipped, or none>
- repo-specific evidence family: <manifest | package verifier | public API docs | sample app/downstream smoke>
- not substituted by: <CI green does not replace visual evidence / package verifier does not replace host smoke / etc.>
```

## Repo-specific evidence families to keep separate

各 repo の強い guard family は、その repo の codebase と review history に合わせて育っています。横断 issue では観測語彙だけをそろえ、次の family を同じ仕組みに置き換えません。

- `tree_view`: manifest-backed contract、docs drift guard、package entrypoint smoke を主 family とする。docs-portal は manifest の存在を evidence として読むが、RFK / RTP に manifest 形式を要求しない。
- `rails_table_preferences`: package verifier、docs source-of-truth、release checklist、manual QA matrix を主 family とする。TreeView 型 manifest や RFK 型 sample app evidence に寄せて置き換えない。
- `rails_fields_kit`: public API docs family、package exports smoke、sample app / downstream smoke を主 family とする。package-root helper の採否や remote search behavior は merged upstream docs と current app code を確認してから書く。
- `docs-portal`: representative downstream smoke、rollback note、release train handoff を主 family とする。Gemfile / lockfile bump、host app screen behavior、business route / permission は upstream guard の成功だけで完了扱いにしない。

## Release train handoff boundary

`#3339` / `#2555` / `#3623` / `#858` の判断をこの playbook で確定しません。ここで固定するのは、release train handoff に添える観測メモの shape です。

- `#3339`: known-good baseline gate の順序や採用判断は、対象 PR / Issue の最新 CI と human gate に戻す。
- `#2555`: package-root public surface の採用順は、merged upstream surface と repo-specific evidence family を読んで判断する。未merge proposal を current support にしない。
- `#3623`: visual evidence は browser-capable batch / review queue に戻す。source spec、docs-quality、CI success だけで layout/readability を完了扱いにしない。
- `#858`: 3 gem release train の target SHA、Gemfile / lockfile 更新、representative smoke、rollback target は child issue / PR に残す。この playbook は 3 gem 同時 bump や known-good revision を決めない。

## Dependency / security observation lane

Dependency / security observation は、同じ `green` でも意味が違う evidence を混同しないための補助 lane です。`npm audit`、Bundler audit、GitHub security alerts、Dependabot PR、release checklist、CI success はそれぞれ別の信号として読み、1 つが green でもほかの確認を完了扱いにしません。

| repo / surface | primary observation | 補助 evidence | 書いてよいこと | 書かないこと |
| --- | --- | --- | --- | --- |
| `tree_view` / `tree_view-rails` | `tree_view-rails#2493` の dependency audit CI guard candidate、Dependabot PR、package-lock / Gemfile.lock drift | package verifier、release checklist、GitHub security alerts の確認結果 | audit CI guard は candidate として扱い、導入判断は `tree_view-rails` 側 issue / PR に戻す | `tree_view-rails#2493` の未確定方針を current support や required check として固定しない |
| `rails_table_preferences` | package verifier、release checklist、CI、Dependabot PR の読み分け | docs index / README family、manual QA、security-adjacent review comment | package-root export や copied controller file の evidence と dependency freshness を分ける | verifier green だけで security alert / audit remediation 完了と書かない |
| `rails_fields_kit` | release evidence docs、sample app evidence、package-root helper evidence、CI | package exports smoke、public API docs drift guard、Dependabot PR | helper / package evidence と dependency / security observation を PR body で別項目にする | sample app smoke success を GitHub security alert や npm/Bundler audit success の代替にしない |
| `docs-portal` | Docusaurus dependency PR、security-audit job、downstream docs build / CI freshness | docs-quality、Docusaurus build、lockfile freshness、Dependabot PR body | PR head SHA と workflow run head SHA をそろえて、dependency PR / audit / docs build のどれを見たかを明記する | stale PR head の CI success、Dependabot metadata、docs-quality success をまとめて security pass と書かない |

Dependency / security の共通化は、PR / issue comment template や release checklist の確認項目までに留めます。repo ごとの CI guard、audit workflow、branch protection、required checks、security alert policy、lockfile refresh、audit failure 修正が必要になった場合は、この playbook では決めず、対象 repo の個別 issue に戻します。

## Review checklist

1. 対象 gem の public surface 正本を 1 つ決める。
2. public docs がその surface を説明しているか、docs drift guard または release checklist の有無を確認する。
3. package-root import、direct entrypoint、`.d.ts`、manifest、package verifier のうち、今回の downstream smoke に必要な evidence がどこまであるかを見る。
4. upstream evidence と docs-portal representative smoke を分けて PR body / issue comment に記録する。
5. open PR、proposal、未 merge docs、未確定 target SHA を release-facing docs に先取りしない。
6. upstream の仕組みを統一する必要が出た場合は、この docs issue で決めず、対象 upstream repo の issue に戻す。
7. dependency / security observation を扱う場合は、audit、security alert、Dependabot、release checklist、CI success を別 evidence として記録する。
8. release train handoff では workflow run、head SHA、compare freshness、skipped job、visual evidence の有無を同じ小見出しで書く。
9. TreeView / RTP / RFK の evidence family を同じ script、manifest、package verifier に寄せる判断が必要になったら止める。

## update log に残す最小項目

```text
- gem: <tree_view | rails_fields_kit | rails_table_preferences>
- public surface checked:
  - <manifest / public_api.md / README + docs index>
- docs drift / release guard checked:
  - <guard name or docs path>
- package evidence checked:
  - <package exports / verifier / .d.ts / built gem gate>
- dependency / security observation checked:
  - <npm audit / Bundler audit / GitHub security alert / Dependabot PR / CI job / skipped with reason>
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
