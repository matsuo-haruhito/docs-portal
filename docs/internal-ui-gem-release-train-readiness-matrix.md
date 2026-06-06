# internal UI gem release train readiness matrix

この文書は、`#858` の release train で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を bump する前に、package-root JavaScript surface、Vite / bundler alias、importmap / setup diagnostics、public API docs guard の readiness を同じ粒度で読むための matrix です。

`docs/internal-ui-gem-release-train-current-queue.md` は release train の queue / gate / evidence template、`docs/internal-ui-gem-public-surface-package-verification-matrix.md` は public surface と package verification の責務境界、`docs/internal-ui-gem-js-resolver-matrix.md` は import / resolver 境界を扱います。この文書は、それらを release train 前の確認順に並べる入口です。

## 使い方

- `Gemfile` / `Gemfile.lock` を更新する前に、対象 gem の current pin、upstream distance、package-root / direct entrypoint、diagnostic guard、public API docs guard、downstream smoke 候補を同じ行で確認します。
- open upstream PR / issue は current support として扱わず、`merge 後に再確認`、`human gate`、`Planner gate`、`ready docs sync` のいずれかで記録します。
- target SHA、known-good revision、Gemfile bump、runtime smoke 成功宣言はこの文書で決めません。実行 PR の body / comment に from / to SHA、representative smoke、rollback target を残します。

## 確認日時と根拠

- 確認日時: 2026-06-06 JST scheduled Docs Sync run
- downstream 正本: `docs-portal` current `main` の `Gemfile`、`app/frontend/entrypoints/application.js`、`vite.config.ts`
- upstream 正本: 各 upstream repo の current `main` compare、関連 issue / PR、README / docs / manifest / package guard
- この run での分類: `docs-missing` / `docs-sync`

## Current pins と upstream distance

| gem | docs-portal current pin | upstream `main` distance from pin | current downstream import / resolver | release train での読み方 |
| --- | --- | --- | --- | --- |
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `ahead_by: 582` / `behind_by: 0` | current `application.js` では package-root controller import 未採用。current `vite.config.ts` に `tree_view` alias なし | JS hook adoption を先取りせず、sidebar tree / detail tree / persisted state / route context の smoke と upstream manifest-backed surface を分ける |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `ahead_by: 677` / `behind_by: 0` | `RailsTablePreferencesController` を package root `rails_table_preferences` から import。`vite.config.ts` は package root と `rails_table_preferences/controller` の alias を持つ | package-root export guard と known-good revision / smoke scope の human gate を分ける。direct entrypoint は documented fallback として扱う |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `ahead_by: 425` / `behind_by: 0` | `TomSelectController` を package root `rails_fields_kit` から import。`vite.config.ts` は package root と `rails_fields_kit/tom_select_controller` の alias を持つ | package-root helper export、setup doctor、importmap pins、bundler alias route を upstream evidence として読み、host app smoke は `admin/document_sets` form に閉じる |

## Readiness matrix

| gem | package-root import path | direct / subpath import | Vite / bundler alias | importmap / setup diagnostics | public API docs / manifest / guard | downstream smoke surface | current blocker / next evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `tree_view` | Upstream `config/public_api_manifest.yml` と public API docs を確認する。docs-portal current main は package-root JS hook をまだ import していない | Downstream docs で gem 内部 path を durable import として書かない。package-root を入口に扱う | docs-portal current `vite.config.ts` に alias なし。JS adoption issue が来た時点で追加要否を判断する | importmap / setup generator の visibility は upstream docs / package guard を正本にする | manifest-backed surface は強い signal。`tree_view-rails#1400` は `TreeViewRemoteStateValues` docs sync、`tree_view-rails#1422` は large-tree docs 導線 | sidebar tree、detail tree、persisted state、route context、windowed / lazy / pagination docs cue | `tree_view-rails#1400` は docs ready。manifest / TypeScript declaration / node-shape guard に human gate が残る場合は current support として先取りしない |
| `rails_table_preferences` | docs-portal current main は package root `rails_table_preferences` を default として使う | `rails_table_preferences/controller` は documented fallback / migration note。default contract に昇格させない | current `vite.config.ts` は package root と direct controller alias を持つ。host app resolver policyは docs-portal 側の責務 | importmap route より bundler / Vite adoption が中心。upstream docs / package verification を確認材料にする | `rails_table_preferences#678` が package-root export docs / smoke guard の ready lane。TypeScript declaration や package verifierは upstream gate | `admin/document_sets` editor、stable column key、mounted save、filter / preset smoke。RTP human gateでは table key / rollback target を別に残す | `rails_table_preferences#678` を先に読む。`#789` known-good revision / smoke scope の human gateを越えるまで broad bump をしない |
| `rails_fields_kit` | docs-portal current main は package root `rails_fields_kit` を default として使う | `rails_fields_kit/tom_select_controller` は documented fallback。new helper / controller helper は README or `doc/public_api.md` で public export確認後に扱う | current `vite.config.ts` は package root と direct controller alias を持つ。bundler alias は host app responsibility | `rails_fields_kit#734` は importmap pins / package exports guard、`rails_fields_kit#1097` は setup doctor bundler alias visibility gate | `rails_fields_kit#1078` は package-root actual exports と docs table の双方向 guard。helper final shape を docs-portal 側で固定しない | `admin/document_sets` form の selected value保持、placeholder、invalid rerender、Tom Select wiring / RFK remote picker | `#1078` は needs-human、`#734` も needs-human。`#1097` は feature gateとして readyだが、host app bundler policyをgem側へ寄せすぎない |

## Upstream queue の読み分け

| queue | 状態 | release train 前の扱い |
| --- | --- | --- |
| `rails_table_preferences#678` | `status:ready-for-agent` / `agent:planned` / `risk:low` | package-root export guard を先に見る。docs-portal 側では guard の採否や manifest 化を決めず、upstream merge 後に package-root surface を再確認する |
| `rails_fields_kit#1078` | `status:needs-human` / `agent:planned` / `risk:low` | actual package-root export と public API docs table の双方向 guard。helper final state / docs sync 順序に human gate が残るため、current support として先取りしない |
| `rails_fields_kit#734` | `status:needs-human` / `agent:planned` / `risk:low` | importmap pins と package exports の drift guard。future subpath export を先取りせず、current 2 entrypoint の対応だけを確認材料にする |
| `rails_fields_kit#1097` | `status:ready-for-agent` / `agent:planned` / `risk:medium` | setup doctor が bundler alias route をどこまで可視化するかの feature gate。host app toolchain policy を gem 側に持ち込まないことを確認する |
| `tree_view-rails#1400` | `status:ready-for-agent` / `agent:planned` / `track:docs` | `TreeViewRemoteStateValues` の public API docs sync。TreeView は manifest-backed surface の基準 repoとして読めるが、runtime export shape変更には広げない |
| `tree_view-rails#1422` | `status:ready-for-agent` / `track:docs` | large-tree docs 導線の補強。docs-portal release trainでは large / partial tree docs cue の確認入口として読む |
| `docs-portal#2108` | open docs PR / docs-quality success / ci success / docs-only | 2026-06-05 snapshotの active PR。target SHA や runtime smoke成功ではなく、dated snapshotとして読む |
| `docs-portal#858` | `status:too-large` | parent / hub。3 gem bump全体をこの文書や #2151 だけで完了扱いにしない |

## PR / Issue に残す update log template

```text
- upstream readiness:
  - gem:
  - current pin:
  - upstream distance checked at:
  - package-root / direct entrypoint evidence:
  - docs / manifest / package guard evidence:
  - open PR / issue gates:
- downstream docs-portal smoke:
  - host app surface:
  - automated check:
  - manual evidence:
  - rollback target:
- boundary:
  - target SHA / Gemfile bump / runtime smoke success is not decided by this docs-only matrix.
```

## Stop conditions before bump PR

- target SHA を作業直前に再計測できない
- `Gemfile.lock` を正しく再生成できない
- representative smoke を実行または確認できない
- open upstream PR / proposal を current support として書く必要がある
- `#789` や upstream needs-human issue の採否を docs-portal 側で決める必要がある
- 複数 gem の同時 bump、UI redesign、DB / auth / external API、business spec 判断が必要になる

この条件に当たる場合は、Gemfile / runtime code を触らず、対象 issue に停止理由と再開条件を残します。

## 関連 docs

- [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md)
- [internal UI gem upstream readiness snapshot](./internal-ui-gem-upstream-readiness-snapshot.md)
- [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md)
- [internal UI gem JS resolver matrix](./internal-ui-gem-js-resolver-matrix.md)
- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md)
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md)

この matrix は、3 gem の package policy を docs-portal 側で決めるものではありません。upstream evidence、downstream smoke、human gate、target SHA selection を分けて、release train PR の review cost を下げるための入口です。
