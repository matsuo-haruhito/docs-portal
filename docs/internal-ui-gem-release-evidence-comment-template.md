# internal UI gem release evidence comment template

このメモは、`docs-portal` と 3 つの internal UI gem (`rails_fields_kit` / `tree_view-rails` / `rails_table_preferences`) の issue / PR で、release evidence と review evidence を同じ粒度で残すための短いテンプレートです。

詳細な public surface と package verification の責務境界は [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md)、代表 smoke と rollback note は [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md)、browser-capable visual evidence は [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md) を正本にします。このメモは、それらを PR comment に貼りやすい形へまとめる入口です。

## 対象

次のような comment / PR body update で使います。

- upstream gem の PR が green / mergeable / merged のどの段階かを記録する
- docs-portal の pinned ref bump や representative smoke の証跡を残す
- CI success、source review、browser evidence、sample app evidence、package verifier evidence、downstream smoke を混同しない
- review follow-up で、残る human gate / visual evidence / downstream smoke を短く明記する

このテンプレートは code / workflow / Gemfile / manifest schema を変更する指示ではありません。実際の bump、browser screenshot 取得、PR review、merge 判断は各 issue / PR に戻します。

## Evidence glossary

| evidence | 何を示すか | 示さないこと |
| --- | --- | --- |
| exact-head workflow run | 対象 head SHA の GitHub Actions が成功 / 失敗 / pending であること。combined status が空でも workflow run を優先して見る | visual readability、downstream adoption、merge 可否の最終判断 |
| source-level docs / spec review | 変更ファイル、source spec、docs signal が intended surface を守っていること | 実ブラウザ layout、sample app 動作、host app smoke |
| browser-capable visual evidence | desktop / narrow viewport / iframe などで cue や layout が読めること | CI success、package verifier、release train readiness |
| sample app / package-root helper evidence | upstream sample app や public helper / package-root export が read-only contract として確認できること | docs-portal の representative smoke、host app の business rule |
| package verifier / docs signal / public API manifest | upstream repo が package contents / docs / public API surface を guard していること | docs-portal 側の target SHA 採用、manifest schema の最終判断 |
| downstream representative smoke | docs-portal の代表画面 / request spec / manual check が from SHA -> to SHA で壊れていないこと | upstream PR の review、3 gem 共通の package policy |
| rollback note | bump や adoption PR で戻す ref / revert 対象 /未確認 surface が分かること | rollback 実行、release 承認、顧客判断 |

## Public surface change checklist

public surface 変更後の follow-up issue を切るときは、1 Issue に何を含めるかを先に分類します。ここでの分類は Planner / Reviewer / Workflow Manager の判断をそろえるためのもので、3 gem の実装方針、package policy、target SHA、visual approval をこの repo 側で確定するものではありません。

| 分類 | 同じ Issue に含めてよいもの | 分けるもの |
| --- | --- | --- |
| runtime public API / helper / export | merge 済み code / docs / manifest / package export に対する read-only evidence、docs drift guard、package contents guard の代表確認 | API 採否、helper 名変更、breaking change、未 merge PR の shape 固定 |
| docs-only public contract clarification | current main の README / public API docs / release guide / runbook の導線整理、正本 docs へのリンク、Issue / PR comment template の補強 | runtime code、Gemfile / lockfile、workflow、upstream docs の変更 |
| package contents / release evidence guard | package-root import、direct entrypoint、built gem / npm artifact、release checklist に対する guard や evidence comment | package verifier policy の横断統一、manifest schema redesign、security / audit remediation 全体 |
| visual evidence / browser evidence | desktop / narrow / iframe など、layout readability や visual artifact の証跡形式、PR comment の最小 template | UI 実装修正、visual approval の最終判断、pixel diff / full visual regression CI 導入 |
| downstream docs-portal smoke / release train | from SHA、to SHA、代表 screen / request spec / manual smoke、rollback target、未確認 surface の明記 | 3 gem 同時 bump、target SHA の人間判断、upstream package policy や public API 採否 |

### Issue slicing prompts

- `source of truth`: public surface の正本は merged code、public API docs、manifest、package verifier、release checklist のどれか。
- `evidence family`: 今回の完了条件は docs signal、package guard、visual evidence、downstream smoke のどれか。CI success と visual approval は別欄にする。
- `same PR scope`: docs-only / spec-only / package verifier / runtime のどれか 1 つを主軸にする。複数必要なら、なぜ同じ根本原因かを書く。
- `follow-up split`: browser evidence、release train bump、security audit、human adoption decision は、同時に完了できないなら別 Issue に戻す。
- `current support`: open PR、proposal、未確定 helper 名、未取得 screenshot、古い CI head は current support として書かない。

## Repo family matrix

| repo | 主 evidence family | comment で残す最小情報 | 戻す先 |
| --- | --- | --- | --- |
| `rails_fields_kit` | package-root helper、sample app、public API docs、release evidence docs | package-root export / helper name、selected value / invalid rerender / sample app or visual reference、docs-portal の対象 form | RFK upstream PR / docs、または docs-portal `#1300` / release train child |
| `tree_view-rails` | public API manifest、TypeScript declaration、docs signal、browser-capable mockup evidence | manifest / public docs / mockup evidence、sidebar tree / detail tree の downstream smoke 要否 | TreeView upstream PR / docs、または docs-portal `#1301` / release train child |
| `rails_table_preferences` | package verifier、docs index、manual QA、browser smoke | package-root `RailsTablePreferencesController`、table key / stable column key / mounted engine save / visual smoke 要否 | RTP upstream PR / docs、または docs-portal `#789` human gate |
| `docs-portal` | downstream smoke、pinned ref、Docusaurus docs build、security audit | current pin、from / to SHA、representative screen / spec、workflow run、rollback target | docs-portal issue / PR。upstream gem public contract は各 upstream repoへ戻す |

## PR / Issue comment template

該当しない項目は `not applicable` と書き、未 merge の signal は `pending upstream` として current support から外します。

```text
release / review evidence:
- target:
  - repo / gem:
  - issue / PR:
  - head SHA:
  - base / compare freshness:
- exact-head CI:
  - workflow run:
  - conclusion:
  - combined status:
- changed scope:
  - files:
  - docs-only / spec-only / runtime:
- upstream evidence:
  - public surface source:
  - package verifier / manifest / docs signal:
  - source review result:
- visual evidence:
  - required: <yes | no>
  - desktop:
  - narrow viewport:
  - embedded / iframe:
  - limits:
- downstream docs-portal evidence:
  - current pin:
  - from SHA:
  - to SHA:
  - representative smoke:
  - rollback target:
- remaining gates:
  - human review:
  - browser evidence:
  - downstream smoke:
  - dependency / merge order:
- next queue:
  - <upstream review | docs-portal release train | visual evidence batch | no downstream action>
```

## Short examples

### CI green but visual evidence pending

```text
release / review evidence:
- target: docs-portal#3506, head <sha>, compare fresh / stale: <value>
- exact-head CI: ci #..., success; combined status empty
- changed scope: runtime UI cue + source spec
- visual evidence: required yes; desktop / embedded / narrow viewport not attached
- downstream docs-portal evidence: not a release train bump
- remaining gates: browser-capable visual evidence and latest main refresh before merge
- next queue: visual evidence batch / human review
```

### Upstream PR green but not current support

```text
release / review evidence:
- target: tree_view-rails#...., head <sha>
- exact-head CI: success
- upstream evidence: public API manifest / docs signal pending merge
- downstream docs-portal evidence: current pin unchanged; no docs-portal smoke yet
- remaining gates: upstream merge and downstream representative smoke
- next queue: docs-portal release train after upstream merge
```

### Docs-only cross-repo evidence sync

```text
release / review evidence:
- target: docs-portal#3660
- changed scope: docs-only, no Gemfile / workflow / runtime change
- upstream evidence: existing matrix / visual runbook / adoption map
- visual evidence: required no
- downstream docs-portal evidence: not applicable
- remaining gates: reviewer chooses whether template wording is sufficient
- next queue: no downstream action
```

## Guardrails

- CI success を visual evidence や downstream smoke の代替にしません。
- browser-capable evidence が acceptance に含まれる場合、source spec / CSS inspection だけで完了扱いにしません。
- upstream の open PR / proposal を docs-portal の current support として書きません。
- package verifier、manifest schema、TypeScript declaration policy は upstream repo で判断します。
- docs-portal の route、authorization、business copy、field params、table key、rollback target は downstream evidence として残し、upstream gem の一般仕様へ昇格しません。
- PR を merge しません。merge 判断は reviewer / human gate に戻します。

## 関連

- `#3702`: public surface 変更時の docs / package guard / release evidence checklist 共通化
- `#3660`: このメモの追加元
- `#3339`: release train 前の known-good baseline gate
- `#2555`: package-root / package-entrypoint public surface の採用順
- `#3623`: UI gem / docs visual evidence batch
- `#858`: downstream smoke 付き release train の親整理
