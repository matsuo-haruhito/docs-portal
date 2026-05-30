# internal UI gem visual evidence runbook

## 目的

`docs-portal` が downstream host app として使う `rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の static visual artifact を変更した PR で、最低限どの確認証跡を残すかをそろえるための runbook です。

screen-by-screen adoption や pinned ref 更新の責務境界は [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) を正本にし、この文書では visual reference、mockup、focused HTML の確認記録だけを扱います。

## 対象になる artifact

次のような変更は、この runbook の対象です。

- `rails_fields_kit` の static visual reference や focused HTML
- `tree_view-rails` の mockup、persisted state guide 用の HTML / CSS artifact
- `rails_table_preferences` の editor / table / responsive row mockup
- docs-portal 側で downstream smoke の判断材料にする HTML、PDF render、screenshot、CSS inspection record

production UI の実装、runtime JavaScript、CI workflow への screenshot job 追加、upstream gem の API 設計はこの runbook だけでは決めません。

## artifact / evidence の役割分担

次の matrix を、`#903` / `#991` / `#904` の pinned ref update train と upstream quality gate issue の共通参照にします。target SHA、実際に通した smoke、rollback target は各 child issue / PR に残し、この表ではどの種類の evidence を正本にするかだけを決めます。

| 領域 | 代表 artifact | 優先する evidence | docs-portal 側で見ること | この issue で広げないこと |
| --- | --- | --- | --- | --- |
| `tree_view-rails` | `docs/mockups/`、persisted state guide 用 HTML / CSS | static artifact は link / heading / nonblank / sample region の lightweight check。browser smoke は mockup が実操作を持つ場合だけ upstream issue で扱う | `#903` では sidebar tree、detail tree、persisted state の representative smoke と rollback note を残す | downstream 採用前の JS hook 追加、全 repo 一律 Playwright 化、screenshot baseline |
| `rails_fields_kit` | `doc/*_visual_reference.html`、focused field HTML | visual reference は lightweight render / source inspection を優先し、focus / selected / error state の確認範囲を PR comment に残す | `#991` では `admin/document_sets` form の selected value、placeholder、validation rerender を代表 smoke にする | helper export 設計変更、host app の screen-by-screen form redesign、full visual regression |
| `rails_table_preferences` | generated demo screen、visual overview、editor / table mockup | generated demo と host-app integration は browser / system smoke を優先し、static mockup は DOM / CSS inspection で補う | `#904` では `admin/document_sets` の editor / filter / preset、mounted engine save、必要時だけ embedded table seam を確認する | known-good revision の human gate 代替、preview iframe fallback の仕様判断、全 table への一括 smoke 追加 |
| `docs-portal` downstream | representative request / system spec、manual spot check、PR update log | pinned ref update train の acceptance evidence として、対象画面・spec・結果・rollback target を 1 セットで残す | [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) の 3 gem 共通 verification matrix と update log template を正本にする | upstream artifact の最終 design review、screenshot approval process の新設、pinned ref 更新そのもの |

static visual reference / mockup は「表示対象が非空で、主要見出し・リンク・sample region が崩れていないこと」を軽量に守ります。generated demo や host-app integration のように実操作が意味を持つものは、browser / system smoke で代表導線を守ります。downstream smoke は upstream artifact の代替ではなく、pinned ref 更新時に docs-portal の代表画面が壊れていないことを示す acceptance evidence です。

## pinned ref update train からの参照方法

- `#903` / `#991` / `#904` では、この matrix で evidence 種別を選び、実際の from / to SHA、通した smoke、rollback target は各 child issue / PR の update log に残します。
- `rails_fields_kit#466` や `tree_view-rails#717` のような upstream quality gate issue では、static artifact の軽量 check と browser smoke の境界がこの matrix と矛盾しないかだけ確認します。
- screenshot approval、pixel baseline、full visual regression suite の導入判断は、この runbook では扱いません。必要になったら別 issue で、対象 repo と採用範囲を切って判断します。

## PR に残す最低限の証跡

static visual artifact を更新した PR では、PR 本文または review follow-up comment に次を 1 セットで残します。

- 対象 artifact: 変更した HTML / docs / mockup / visual reference の path
- desktop 観点: 主表示、focus / hover / selected / empty など対象状態のうち確認したもの
- narrow viewport 観点: 折り返し、横スクロール、sticky / pinned、overflow、文字切れのうち対象になるもの
- evidence 種別: screenshot、HTML renderer、PDF render、source inspection、CSS arithmetic record、downstream smoke のどれを使ったか
- 未取得の証跡: 実ブラウザ screenshot が取れていない場合は、その理由と代替 evidence
- downstream 影響: docs-portal 側の representative smoke を必要とするか、upstream artifact review に閉じるか

「CI green」だけでは visual artifact の証跡として扱いません。CI が通っていても、表示状態をどう見たかを短く残します。

## desktop / narrow viewport の最低確認観点

### desktop

- 主表示で artifact の対象 UI が見切れていない
- label、badge、button、helper text が重ならない
- focus / selected / expanded / error など、その PR が変えた state が 1 つ以上確認されている
- table / tree / token / field の alignment が、既存 docs や mockup の目的と矛盾していない

### narrow viewport

- 長い label や badge が親要素からはみ出さない
- 横スクロールが前提の table / tree では、sticky / pinned / spacer / focus outline のどこを確認したかが分かる
- responsive row や compact layout では、主要 action が押せる位置に残っている
- screenshot がない場合でも、source inspection で確認した min-width、overflow、wrap、z-index、CSS variable の根拠を残す

## screenshot が取れない場合の代替 evidence

実行環境の制約で Playwright や実ブラウザ screenshot が取れない場合は、次の代替 evidence を組み合わせます。

- HTML renderer / PDF render: static HTML や docs artifact が非空で、主要 section が崩れていないことを確認する
- source inspection: responsive rule、ARIA / focus class、DOM structure、data attribute の整合を見る
- CSS arithmetic record: pinned offset、width、overflow、z-index、focus outline などの計算前提を PR comment に残す
- downstream smoke: docs-portal の representative screen で request / system spec や manual spot check を使う

代替 evidence は screenshot と同等ではありません。特に hover、focus ring、実ブラウザの font rendering、mobile viewport の重なりは限界として明記します。

## repo-local release gate との分担

- `rails_fields_kit`: visual reference の state 追加や focus-visible 確認は upstream repo の release gate issue に残し、docs-portal 側では canary form に影響するかだけを判断します。
- `tree_view-rails`: persisted state mockup や guide HTML の render evidence は upstream repo に残し、docs-portal 側では sidebar tree / detail tree / persisted state の representative smoke を別に扱います。
- `rails_table_preferences`: editor row、fixed / pinned column、responsive table の source inspection や screenshot 代替は upstream repo に残し、docs-portal 側では `admin/document_sets` などの downstream list smoke に閉じます。

## issue / PR コメントの短いテンプレート

```text
visual evidence:
- artifact: docs/path-or-visual-reference.html
- desktop: <confirmed states>
- narrow viewport: <confirmed states or not checked>
- evidence: <screenshot | HTML/PDF render | source inspection | CSS arithmetic | downstream smoke>
- limits: <missing browser evidence or human review point>
- downstream: <none | docs-portal representative smoke path>
```

## 非目標

- すべての repo に Playwright screenshot job を必須追加すること
- visual review の最終判断を自動化すること
- upstream gem の public API / helper behavior を docs-portal 側で再定義すること
- production CSS / runtime JS の変更をこの runbook から始めること