# internal UI gem visual evidence batch checklist

## 目的

`rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の static visual / docs artifact PR に残る browser-capable evidence を、小さな batch と共通コメント形式で確認するための companion note です。

この note は [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md) の運用補助です。CI success、source review、browser evidence、human adoption decision を混同しないために、対象 PR と evidence comment の戻し先だけを整理します。

## first batch

まず `rails_fields_kit` の static visual PR 群を優先します。いずれも runtime redesign や helper implementation 修正には広げず、desktop / narrow viewport の読みやすさと ownership wording を確認して PR comment に戻します。

| repo / PR | 見る artifact | desktop 観点 | narrow viewport 観点 | comment の戻し先 |
| --- | --- | --- | --- | --- |
| `rails_fields_kit` #1321 | native constraint boundary visual reference | constraint lane の読み順、host-app validation ownership、caption の誤読がないこと | 約390px幅で label / helper / error / constraint copy が重ならないこと | PR #1321 |
| `rails_fields_kit` #1296 | host feedback lifecycle visual reference | loading / success / failure / no-event の状態差が横並びで読めること | state card の折り返し、caption、helper-specific cue が親幅に収まること | PR #1296 |
| `rails_fields_kit` #1295 | helper choice comparison companion artifact | helper choice の比較軸と non-goal が caption から読めること | comparison card の列落ち後も helper 名と責務差が混線しないこと | PR #1295 |

## second batch candidates

| repo / PR | 扱い |
| --- | --- |
| `tree_view-rails` #1596 | README first visual の human visual review。RFK batch 後に desktop / narrow で README 上の見え方を確認する |
| `rails_table_preferences` #1316 | visual overview rendered evidence boundary は既に planned 済み。ここでは重複実装せず参照だけにする |
| `rails_fields_kit` #1263 / #1246 | 必要なら second batch。mergeability 解消や design 採用判断はこの note の完了条件にしない |

## viewport baseline

- desktop: 1366px 前後。artifact 全体の主要 lane、caption、ownership wording、link / docs map からの到達性を見る。
- narrow: 390px 前後。長い label、badge、helper text、caption、table / card の折り返しと重なりを見る。
- screenshot が取れない場合は、source inspection、HTML render、manual spot check のどれで代替したかを明記する。

## evidence comment template

```text
browser-capable visual evidence:
- PR / artifact: <repo#number> / <path>
- head: <branch or SHA>
- desktop viewport: <width and confirmed states>
- narrow viewport: <width and confirmed states>
- pass / concern: <short result>
- evidence type: <screenshot | browser smoke | HTML render | source inspection | manual spot check>
- limits: <missing hover / focus / real browser / adoption decision if any>
- decision handoff: final merge / adoption judgment stays on this PR
```

## 境界

- この batch issue は merge 判断をしません。各 PR に evidence comment を戻し、review / merge 判断は PR 単位に残します。
- CI green だけでは visual evidence 完了にしません。
- static visual artifact の redesign、screenshot baseline、pixel diff、visual regression CI、3 gem 同時 release / bump、docs-portal Gemfile pin 更新は扱いません。
- browser evidence の過程で実装不備を見つけた場合は、対象 PR の review comment または別 issue に分けます。

## #2539 checklist

- [x] first batch の対象 PR を RFK static visual 群に絞る
- [x] desktop / narrow viewport の代表幅を明記する
- [x] evidence comment template を用意する
- [x] CI success と visual adoption decision の責務を分ける
- [x] second batch と非目標を分ける
