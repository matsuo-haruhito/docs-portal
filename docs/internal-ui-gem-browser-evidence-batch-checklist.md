# internal UI gem browser evidence batch checklist

## 目的

`rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の static visual artifact や docs visual artifact を review するときに、desktop / narrow viewport の browser-capable evidence を同じ粒度で残すための checklist です。

この文書は [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md) の companion です。CI success、source review、rendered browser evidence、human adoption decision を混同しないことを目的にし、各 PR の merge 可否はこの checklist では決めません。

## 対象 batch

first batch は `rails_fields_kit` の static visual PR 群を優先します。second batch は `tree_view-rails` の static mockup / README visual candidate PR 群を優先します。reviewer は各 PR で head SHA、workflow run、mergeable、compare freshness を確認してから evidence comment を残してください。

| batch | repo / PR | artifact focus | browser-capable review focus | judgment boundary |
| --- | --- | --- | --- | --- |
| first | `matsuo-haruhito/rails_fields_kit#1321` | native constraint boundary visual reference | desktop / narrow で constraint lane の読みやすさ、host-app validation ownership の誤読がないこと | mergeability 解消や adoption 判断は PR 側に戻す |
| first | `matsuo-haruhito/rails_fields_kit#1296` | host feedback lifecycle visual reference | desktop / narrow で feedback state、caption、ownership wording が崩れないこと | lifecycle behavior や helper API はこの checklist で決めない |
| first | `matsuo-haruhito/rails_fields_kit#1295` | helper choice comparison companion artifact | helper comparison card の折り返し、state label、caption の読みやすさ | helper choice の採用可否は PR / issue 側で判断する |
| second | `matsuo-haruhito/rails_fields_kit#1263` / `matsuo-haruhito/rails_fields_kit#1246` | visual reference / proposal-adjacent artifact | first batch の結果を踏まえて、必要な viewport と comment 粒度だけを合わせる | mergeability 未確定の場合は evidence だけ返し、完了条件にしない |
| second | `matsuo-haruhito/tree_view-rails#1596` | README first visual | README first viewport で default tree visual が読み取れるか、narrow で text / tree が重ならないか | README adoption / final visual approval は PR 側に戻す |
| second TreeView static | `matsuo-haruhito/tree_view-rails#1648` | `docs/mockups/localized-row-labels.html` の node key / DOM ID boundary note | desktop / narrow で boundary note、same node key / DOM ID table、review focus card が読めること | visual readability evidence だけを返し、node key / DOM ID contract や public API は決めない |
| second TreeView static | `matsuo-haruhito/tree_view-rails#1678` | persisted-state cleanup card、mockup README flow、README visual candidate checklist | desktop / narrow で cleanup retention cue、mockup index 導線、README visual checklist が読めること | cleanup job / retention policy / README asset adoption は PR 側または human review に戻す |
| reference only | `matsuo-haruhito/tree_view-rails#1657` | public hook surface を含む docs / mockup PR | visual evidence 対象に入れる場合も static docs の読みやすさだけを補助確認する | hook 採否や public surface 判断は `docs-portal#2555` 側へ戻す |
| deferred | `matsuo-haruhito/rails_table_preferences#1285` | visible dirty-state UI / ARIA helper | browser-capable review 価値は高いが、freshness / conflict recovery 後の別 tranche で扱う | mergeable 回復前に TreeView static batch へ混ぜない |
| reference only | `matsuo-haruhito/rails_table_preferences#1316` | visual overview evidence boundary | 既に planned 済みのため、rendered confirmation と source-only inspection の境界だけ参照する | 重複実装しない |

## second TreeView static batch notes

`docs-portal#2614` の second batch は、TreeView の static mockup / docs visual PR だけを本体にします。repo 名なしの `#1648` のような参照は docs-portal 内番号に見えるため、evidence comment では必ず `matsuo-haruhito/tree_view-rails#1648` のように repo 名付きで書きます。

この batch で採用する方針は、TreeView static PR 2件に絞って browser-capable evidence の対象と comment 粒度を固定する案です。`matsuo-haruhito/tree_view-rails#1657` は public hook surface を含むため、static docs の読みやすさだけを補助確認し、hook 採否は public surface lane に戻します。`matsuo-haruhito/rails_table_preferences#1285` は dirty-state UI と ARIA helper の visual review 価値がありますが、TreeView static batch には混ぜず、freshness / conflict recovery 後の別 tranche 候補にします。

## viewport baseline

browser-capable evidence は、少なくとも次の 2 幅を基準にします。実環境で多少ずれてもよいですが、comment には実際に使った幅を書いてください。

| viewport | width |見ること |
| --- | --- | --- |
| desktop | 1366px 前後 | 主表示、caption、ownership wording、state label、button / link、focus / selected / error の代表 state が重ならないこと |
| narrow | 390px 前後 | 長い label / badge / caption が親幅からはみ出さないこと、主要 action が押せる位置に残ること、horizontal scroll 前提の artifact では確認した scroll / overflow 境界が分かること |

高さは artifact に合わせて調整してよいです。first viewport だけで判断せず、PR が変えた state が見える位置まで scroll して確認します。

## evidence checklist

各 PR では、次を 1 セットで確認してから comment を残します。

- PR metadata: repo、PR number、head branch、head SHA、mergeable、updated_at
- CI / workflow: combined status だけでなく workflow run の有無と result
- freshness: base branch との差分、behind / diverged の有無
- artifact path: HTML、README、mockup、visual reference など確認対象の path
- desktop: viewport 幅、確認した state、pass / concern
- narrow: viewport 幅、確認した state、pass / concern
- wording: caption、ownership wording、host-app / upstream responsibility の誤読がないか
- limits: screenshot がない、実ブラウザで hover / focus を見ていない、mobile 実機ではない、などの限界
- handoff: evidence 後の判断先が各 PR review / merge decision に戻っていること

## PR comment template

```text
browser-capable visual evidence:
- repo / PR: <owner/repo#number>
- head: <branch> @ <sha>
- CI / workflow: <workflow name / run number / result, or not found>
- freshness: <behind_by / diverged / mergeable>
- artifact: <path>
- desktop viewport: <width>x<height>; <confirmed state / pass / concern>
- narrow viewport: <width>x<height>; <confirmed state / pass / concern>
- wording / ownership: <caption and responsibility boundary note>
- limits: <missing screenshot / hover / focus / human visual review point>
- next judgment: evidence returned to this PR; merge / adoption decision is not decided by the cross-repo batch
```

## pass / concern の書き方

### pass と書ける場合

- desktop と narrow の両方で、対象 artifact の主表示が非空で読める
- caption、ownership wording、state label が重ならず、意味の境界を誤読しにくい
- PR が変えた state を少なくとも 1 つ確認している
- CI success と visual adoption decision を分けて comment している

### concern として返す場合

- narrow viewport で label、badge、caption、主要 action が重なる、または親幅からはみ出す
- host-app-owned UI と upstream gem-owned UI の責務境界を誤読しやすい
- screenshot / browser evidence が未取得なのに visual確認済みのように読める
- head が大きく diverged しており、evidence が current review state とずれる

concern はこの checklist で修正しません。該当 PR に comment し、scope 外の runtime code、CSS redesign、API / helper behavior 変更へ広げないでください。

## この batch で決めないこと

- 各 PR の merge 可否
- known-good revision、Gemfile pin、release train の target SHA
- screenshot baseline、pixel diff、visual regression CI の導入
- static visual artifact の redesign
- runtime Ruby / JavaScript / CSS / helper implementation の変更
- 3 gem の同時 release / bump

必要になった場合は、対象 repo / PR / issue に判断を戻し、この docs-portal checklist では evidence の粒度だけを揃えます。
