# internal UI gem ワークフロー

inclusion: manual

---

## 統合元ファイル一覧

| ファイル | 最終 commit |
|---------|-------------|
| docs/internal-ui-gem-public-surface-guard-playbook.md | 6b49064d2be78c50848e6d3868b97b43b244af2f |
| docs/internal-ui-gem-public-surface-guard-comparison.md | 30852fa57bac9b6373725188e897e3b1e3027a7a |
| docs/internal-ui-gem-visual-evidence-runbook.md | 7350a9a172521833a28b828ca9e1a5567986f85e |
| docs/internal-ui-gem-bump-pr-checklist.md | 44e9e592855b08612aa34119082d077dffc6cec5 |
| docs/internal-ui-gem-browser-evidence-batch-checklist.md | 4ef253fd3c8e9fa561c0d511cfd74e1e78eed6a5 |
| docs/internal-ui-gem-release-evidence-comment-template.md | 59a80266603ff7de0f919be269ce28a18e184de1 |
| docs/host-app-visual-evidence-comment.md | 95bb2be62216c8d59a8427a48d4b56ab2e831576 |

---

## 概要

このスキルは、`tree_view` / `rails_fields_kit` / `rails_table_preferences` の internal UI gem に対する以下のワークフローを統合したものです。

- Public surface guard（upstream 確認の手順・比較観点）
- Visual evidence 収集（PR / Issue に残す証跡の基準と手順）
- Version bump PR の実行手順
- PR / release comment テンプレート

---

## 1. Public Surface Guard ワークフロー

### 目的

pinned ref bump 前に upstream の public surface、docs drift guard、package evidence を確認し、docs-portal 側の representative smoke に必要な情報をそろえる。

### 確認タイミング

- release train (`#858`) の child issue で target SHA を決める前
- upstream の public docs / package entrypoint / verifier が downstream smoke に足りるか比較したいとき
- upstream の public surface 自体が未整理なのか、host app smoke のみ未確認なのかを切り分けたいとき

### gem 別 public surface の正本

| gem | public surface の正本 | docs drift guard | package evidence |
|-----|----------------------|-----------------|-----------------|
| `tree_view` | `config/public_api_manifest.yml`（manifest-backed） | README + `docs/ja/*` / `docs/en/*` / mockups | built gem の JS / CSS / importmap entrypoint |
| `rails_fields_kit` | `doc/public_api.md`（docs-backed） | `doc/setup.md`、`doc/field_helpers.md`、`doc/events.md` 他 | `package.json` exports（package root + `./tom_select_controller`） |
| `rails_table_preferences` | README + `docs/index.md` family（docs-backed） | quick start、production integration checklist、release check docs | `package.json` exports（package root + `./controller`）、package verifier |

### 横断比較の原則

- まず current merged docs / manifest を見る。open PR や proposal を current support として書かない
- host app 固有の params、authorization、query、business copy は upstream gem の contract にしない
- `app/frontend/entrypoints/application.js` と `vite.config.ts` の current wiring を downstream evidence にする
- event detail keys の proposal は upstream で確定してから downstream docs へ入れる
- generator output は downstream adoption 成功の証拠ではない。host app で wiring / smoke を分けて確認する
- TreeView 型 manifest は surface が多く drift しやすい場合の選択肢。3 gem へ機械的にコピーしない

### Evidence lane の選択

PR では最初に主軸 lane を 1 つ選び、足りない証跡だけを補助 lane として残す。

| 主軸 lane | 向いている surface | 代表 evidence |
|-----------|-------------------|--------------|
| manifest-backed contract | helper method、option key、event name、JS export | upstream manifest、compatibility spec、docs drift guard |
| docs-only sync | README、public API docs、release checklist の説明 drift | merged upstream docs、current app docs |
| package verifier guard | package-root import、built gem / npm artifact | package verifier、built artifact check |
| sample app / downstream smoke | host app の screen、form、table | docs-portal request spec、manual smoke、rollback note |
| visual reference evidence | layout、state cue、interactive affordance | visual reference gallery、mockup browser smoke |

### Review checklist

1. 対象 gem の public surface 正本を 1 つ決める
2. public docs がその surface を説明しているか確認する
3. package-root import / entrypoint / verifier のうち必要な evidence がどこまであるか見る
4. upstream evidence と docs-portal representative smoke を分けて PR body に記録する
5. open PR / proposal / 未 merge docs を release-facing docs に先取りしない
6. upstream の仕組みを統一する必要が出たら対象 upstream repo の issue に戻す

---

## 2. Visual Evidence 収集手順

### Evidence の 3 区分

| 区分 | 対象 | 最低限残す evidence |
|------|------|-------------------|
| upstream static docs / mockup | gem の `doc/*visual_reference*.html`、mockup gallery | nonblank、主要 heading / sample region、desktop / narrow の粗い崩れ確認 |
| docs-portal runtime host app UI | admin list / form、viewer tree、Markdown preview | representative screen の browser-capable evidence、確認 viewport |
| PR reviewer evidence | review follow-up comment、manual spot check | screenshot / browser smoke / source inspection / limits を 1 セットで残す |

### Viewport baseline

| viewport | width | 見ること |
|----------|-------|---------|
| desktop | 1366px 前後 | 主表示、caption、state label、button が重ならない |
| narrow | 390px 前後 | label / badge が親幅からはみ出さない、主要 action が押せる位置に残る |

### desktop の確認観点

- 主表示で artifact の対象 UI が見切れていない
- label、badge、button、helper text が重ならない
- PR が変えた state が 1 つ以上確認されている

### narrow viewport の確認観点

- 長い label や badge が親要素からはみ出さない
- 横スクロール前提の table / tree では sticky / pinned の確認箇所が分かる
- 主要 action が押せる位置に残っている

### Screenshot が取れない場合の代替 evidence

- HTML renderer / PDF render: static HTML が非空で主要 section が崩れていない
- source inspection: responsive rule、ARIA / focus class、DOM structure の整合
- CSS arithmetic record: pinned offset、width、overflow、z-index の計算前提
- downstream smoke: docs-portal の representative screen で request spec / manual spot check

代替 evidence は screenshot と同等ではない。hover、focus ring、実 font rendering、mobile viewport の重なりは限界として明記する。

### Evidence checklist（PR ごと）

- PR metadata: repo、PR number、head branch、head SHA、mergeable
- CI / workflow: combined status + workflow run の有無と result
- freshness: base branch との差分（behind / diverged）
- artifact path: 確認対象の path
- desktop: viewport 幅、確認した state、pass / concern
- narrow: viewport 幅、確認した state、pass / concern
- wording: caption と責務境界の誤読がないか
- limits: screenshot 未取得、hover / focus 未確認等の限界
- handoff: evidence 後の判断先が PR review に戻っていること

### pass と書ける条件

- desktop と narrow の両方で主表示が非空で読める
- caption / state label が重ならず誤読しにくい
- PR が変えた state を少なくとも 1 つ確認している
- CI success と visual adoption decision を分けて comment している

### concern として返す条件

- narrow viewport で label / action が重なる、または親幅からはみ出す
- host-app-owned と upstream gem-owned の責務境界を誤読しやすい
- head が大きく diverged しており evidence が current state とずれる

---

## 3. Version Bump PR 手順

### 共通方針

- 1 PR では 1 gem だけを bump する
- `Gemfile` / `Gemfile.lock` 変更前に current pin、candidate target、open gate、latest CI を再確認する
- target SHA はこの手順では決めない。PR body または issue comment に残す
- upstream の package verification / public API guard は docs-portal で再実行しない。host-app integration smoke だけを見る
- `Gemfile.lock` は Bundler の生成結果を正本にする。SHA 行だけの手編集で完了扱いにしない
- runtime UI redesign、business rule、authorization、DB schema は同じ PR に混ぜない

### PR 前 checklist

- [ ] 対象 gem は 1 つだけに決めた
- [ ] package-root / direct entrypoint / resolver / public API guard の現状を確認した
- [ ] representative smoke と rollback target の置き場所を確認した
- [ ] open upstream PR / issue を current support として書かず分類した
- [ ] candidate target の CI / mergeability / release note を作業直前に確認した
- [ ] Bundler で `Gemfile.lock` を再生成できる環境で作業している
- [ ] smoke failure 時の切り分け準備がある

### gem 別 smoke

| gem | host-app smoke | rollback note |
|-----|---------------|---------------|
| `rails_fields_kit` | `admin/document_sets` form: initial render、selected value、invalid rerender、Tom Select wiring | current pin へ戻す |
| `tree_view` | sidebar tree と detail tree: route context、persisted state、Turbo Stream refresh、window offset | current pin へ戻す |
| `rails_table_preferences` | `admin/document_sets` index: editor、stable column key、filter / preset、mounted engine save | current pin へ戻す |

### Stop conditions

次のいずれかに当たる場合は bump PR を作らず停止理由と再開条件を残す:

- target SHA を作業直前に再計測できない
- Bundler で `Gemfile.lock` を再生成できない
- representative smoke を実行または確認できない
- open upstream PR / proposal を current support として扱う必要がある
- 複数 gem の同時 bump や UI redesign が必要になる

---

## 4. PR / Release Comment テンプレート

### Release / review evidence テンプレート

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

### Bump PR body テンプレート

```text
## internal UI gem bump evidence

- gem:
- issue:
- from:
- to:
- upstream readiness checked at:
- open upstream gates:
  - <none / issue / PR / human gate>
- docs-portal host-app smoke:
  - automated:
  - manual:
  - skipped:
- rollback target:
- boundary:
  - upstream package verification / public API / visual reference guard は再実行していません
  - runtime UI redesign / business spec / auth / DB / external API は変更していません
```

### Browser-capable visual evidence テンプレート

```text
browser-capable visual evidence:
- repo / PR: <owner/repo#number>
- head: <branch> @ <sha>
- CI / workflow: <workflow name / run number / result>
- freshness: <behind_by / diverged / mergeable>
- artifact: <path>
- desktop viewport: <width>x<height>; <confirmed state / pass / concern>
- narrow viewport: <width>x<height>; <confirmed state / pass / concern>
- wording / ownership: <caption and responsibility boundary note>
- limits: <missing screenshot / hover / focus>
- next judgment: evidence returned to this PR
```

### Host app visual evidence テンプレート

```text
host app visual evidence:
- head: <commit sha or PR number>
- viewport: <desktop | narrow | mobile | not checked>
- target: <URL / params / role / seed or fixture>
- UI state: <normal | empty | filtered 0 | validation error | selected value | confirmation>
- result: <confirmed in browser | screenshot attached | request spec only | source guard only | not checked>
- CI / guard: <workflow run or spec/source guard evidence>
- limits: <hover/focus/font rendering/narrow viewport/screenshot not checked>
- follow-up: <none | source issue #... | visual evidence issue #...>
```

### PR body への短い書き方

```text
- request spec / source guard: success
- browser visual evidence: not checked in this PR
- follow-up: #NNNN で desktop / narrow viewport を確認予定
```

---

## 共通ガードレール

- CI success を visual evidence や downstream smoke の代替にしない
- browser-capable evidence が acceptance に含まれる場合、source spec / CSS inspection だけで完了扱いにしない
- upstream の open PR / proposal を docs-portal の current support として書かない
- package verifier / manifest schema / TypeScript declaration policy は upstream repo で判断する
- docs-portal の route / authorization / business copy / table key / rollback target は downstream evidence として残し upstream gem の一般仕様へ昇格しない
- PR を merge しない。merge 判断は reviewer / human gate に戻す
- dependency / security observation は CI green と分けて記録する
