# internal UI gem downstream adoption smoke matrix

この文書は、`docs-portal` が `tree_view` / `rails_table_preferences` / `rails_fields_kit` を採用・更新するときに、downstream 側で見る smoke と evidence を 3 gem 共通の列で確認するための matrix です。

詳細な public surface、package verification、release train、visual evidence の正本は既存 docs に残します。この文書では、採用判断の PR / Issue comment に何を同じ粒度で残すかだけを扱います。

## 使い方

1. 対象 gem の行を見て、4 つの evidence 区分を埋める。
2. upstream evidence と docs-portal downstream smoke を同じ evidence として混ぜない。
3. target SHA、Gemfile bump、merge 可否、upstream API 採否はこの文書では決めない。
4. 未 merge の upstream PR / proposal は `pending upstream` として書き、current support として扱わない。

## 4 区分 evidence

| 区分 | 何を見るか | docs-portal 側で残す最小記録 | 完了扱いにしないもの |
| --- | --- | --- | --- |
| upstream known-good / fresh CI | upstream repo の対象 PR / commit / release docs が fresh か | upstream repo、PR / commit、CI または review 状態、merge 済みか pending か | upstream PR green だけで docs-portal 採用完了とはしない |
| public package surface / import path | package-root export、documented direct entrypoint、public API docs、manifest / package contents guard | 参照した docs / manifest / verifier、package-root か direct entrypoint か、fallback の有無 | 未 merge の export 名や manifest schema を durable contract にしない |
| visual evidence / static artifact readability | mockup、visual reference、generated demo、review gallery、manual QA artifact | 見た artifact、desktop / narrow viewport の有無、browser evidence か source inspection か、限界 | CI success や source spec だけで layout / readability acceptance を満たした扱いにしない |
| docs-portal representative downstream smoke | host app の代表画面、request spec、manual smoke、rollback target | screen / spec、from SHA、to SHA、確認結果、rollback target、docs follow-up 要否 | upstream evidence を host app smoke の代替にしない |

## 3 gem common matrix

| gem | upstream known-good / fresh CI | public package surface / import path | visual evidence / static artifact readability | docs-portal representative downstream smoke |
| --- | --- | --- | --- | --- |
| `tree_view` | `tree_view-rails` の README、`docs/ja/*`、release docs、public API manifest、対象 PR / commit の CI を見る。open PR は `pending upstream` とする | package-root entrypoint、`TreeViewEventNames`、`TreeViewControllerIdentifiers`、`registerTreeViewControllers(application)` など documented export を優先する。gem 内部 path を durable import として書かない | mockup gallery、default tree、row status、persisted state / large tree docs cue を見る。static artifact は first-look evidence であり採用完了ではない | sidebar tree、detail tree、persisted state、route context、window offset。片方の tree だけなら未確認側を明記する |
| `rails_table_preferences` | `rails_table_preferences` の README、`docs/javascript_entrypoints.md`、release checklist、package verification / manual QA docs、対象 PR / commit の CI を見る | package root `rails_table_preferences` の `RailsTablePreferencesController` を default とし、`rails_table_preferences/controller` は documented fallback / migration lane として扱う | visual overview、generated demo、editor / table mockup、manual QA artifact を見る。known-good revision の human gate 代替にしない | `admin/document_sets` の editor、stable column key、filter / preset、mounted engine save、必要時だけ embedded table seam。table key と rollback target を残す |
| `rails_fields_kit` | `rails_fields_kit` の README、`doc/public_api.md`、`doc/setup.md`、final release checklist、対象 PR / commit の CI を見る | package root `rails_fields_kit` の `TomSelectController` と public API docs を優先する。direct path は documented fallback の場合だけ使う | visual reference family、focused field HTML、sample app evidence を見る。helper export proposal や host form redesign の採否はここで決めない | `admin/document_sets` form の selected value、placeholder、invalid rerender、Tom Select wiring。remote search を触る場合だけ endpoint と selected value retention を追加する |

## PR / Issue comment template

```text
internal UI gem downstream adoption smoke:
- gem:
- upstream known-good / fresh CI:
  - source:
  - status:
- public package surface / import path:
  - source of truth:
  - import path:
  - pending upstream:
- visual evidence / static artifact readability:
  - artifact:
  - evidence:
  - limits:
- docs-portal representative downstream smoke:
  - screen / spec:
  - from:
  - to:
  - result:
  - rollback target:
  - docs follow-up:
```

## 既存 docs との役割分担

- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md): representative smoke、upstream evidence、更新順、rollback note の詳細 map。
- [internal UI gem release train readiness matrix](./internal-ui-gem-release-train-readiness-matrix.md): release train 前の current pin、upstream distance、readiness signal。
- [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md): public export、TypeScript declaration、manifest、package verification の責務境界。
- [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md): static artifact / host app UI の visual evidence の残し方。
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md): 調査開始時に見る repo-local file、representative screen、release train の読み分け。

## 境界

- この文書は code、Gemfile、Gemfile.lock、runtime view / spec を変更しません。
- target SHA、known-good revision、merge order、human gate は各 child issue / PR を正本にします。
- upstream gem の public API、helper option、manifest schema、package verifier policy は各 upstream repo を正本にします。
- docs-portal 固有の route、permission、business copy、field params、table key は downstream evidence として扱い、upstream public contract にしません。
