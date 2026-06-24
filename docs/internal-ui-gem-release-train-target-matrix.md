# Internal UI gem release train target matrix

この文書は、`docs-portal` の internal UI gem 3本について、次の Gemfile bump / smoke Issue を切る前に見る current snapshot です。`docs/関連gem連携調査runbook.md` と `docs/internal-gem-release-train-smoke.md` は恒常的な運用正本、この文書は 2026-06-13 JST 時点の target ref / downstream smoke / rollback matrix と、2026-06-13 に完了した TreeView first tranche の反映状況として扱います。2026-06-25 JST の横断 refresh は下の `2026-06-25 cross-repo refresh` を優先して読み、古い PR 状態や green CI を current adoption evidence として使わないでください。未merge upstream PR の mergeability は変動するため、表内の値は確認時点付きの snapshot とし、bump PR を作る直前に必ず再測定します。

## Scope

- 対応 Issue: #2962、#2983、#3829
- 対象 gem: `tree_view`, `rails_fields_kit`, `rails_table_preferences`
- この文書で行うこと: current pin、upstream PR 状態、first tranche の完了 / 後続候補、除外または判断待ち PR、代表 smoke、rollback 記録場所を更新する
- この文書で行わないこと: `Gemfile` / `Gemfile.lock` の更新、3 gem 一括 bump、upstream PR code review、upstream merge 判断、browser visual evidence の一括取得

## 2026-06-25 cross-repo refresh

#3829 の docs-only 追従では、#3796 と #3817 の最新コメントを 2026-06-25 JST 時点の横断 snapshot として扱います。これは release train の採用順を読むための入口であり、ここにある open PR を merged current support や downstream target SHA として固定するものではありません。

| lane | 2026-06-25 JST の読み方 | 次に戻す場所 |
| --- | --- | --- |
| `rails_fields_kit` | public surface / helper contract は docs/design lane と分けて読む。#2102 / #2103 / #2129 などは CI success だけで採用せず、freshness 更新、fresh CI、人間の public surface 採否判断を挟む。#2142 / #2143 のような docs/design/semantic boundary 寄りの PR は release blocker ではなく非ブロッキング review 候補として扱う。 | RFK の upstream PR review / merge 判断後、#2576 または #3339 で target SHA、representative smoke、rollback note を再計測する。 |
| `rails_table_preferences` | 2026-06-25 時点で open PR がないため、先に `rails_table_preferences#1650` の known-good SHA / representative CI evidence policy を人間が決める。ここが未確定のまま docs-portal 側の Gemfile bump に進まない。 | `rails_table_preferences#1650` と #3339。known-good baseline が決まってから docs-portal downstream bump / smoke Issue へ戻す。 |
| `tree_view` | TreeView first tranche は #2983 / PR #3019 で完了済み。#2583 の CI token permissions docs sync は merge 済み evidence として扱い、次の横展開は共通 policy vocabulary / evidence discipline の再利用に留める。#2271 など visual / design lane は release train first tranche に混ぜない。 | #3753 などの共通 policy / visual evidence lane。新しい TreeView bump は fresh upstream SHA、smoke、rollback target を持つ別 Issue で扱う。 |
| `docs-portal` local app PR | #3816 / #3820 / #3831 などの local app PR は、UI gem release train の upstream target SHA 判断とは別 queue。CI success や mergeability を UI gem adoption readiness の代替にしない。 | 各 local app Issue / PR。release train matrix には混ぜない。 |
| Docusaurus / dependency lane | #3057 は merge 済み、#3365 などは Docusaurus dependency freshness / audit lane として扱う。internal UI gem release train の first tranche とは分ける。 | Docusaurus dependency / docs build runtime の Issue。Gemfile bump や UI gem smoke へ混ぜない。 |

確認時は combined status が空でも、workflow run、PR metadata、head SHA、compare freshness をセットで見ます。古い green CI、behind / diverged branch、未提出 browser-capable evidence、人間 gate が残る public surface を downstream target evidence にしないでください。

## Current docs-portal pin

`Gemfile` と `Gemfile.lock` の current resolved revision は次のとおりです。この表を #858 / #2576 の古い前提より優先します。

| gem | current resolved revision | upstream main compare / release train state | rollback target |
| --- | --- | --- | --- |
| `tree_view` | `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` | #2983 / PR #3019 で first tranche bump 済み。PR CI `ci #5599` は success。次の TreeView lane を切る場合は、その時点の `tree_view-rails@main` を再測定する | `9c538f9ee7946fa5af24f15c99402a0431677303` |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | 2026-06-13 snapshot では `rails_fields_kit@main` が `ahead_by:720`, `behind_by:0`。2026-06-25 refresh では public surface PR の freshness / human gate を先に見る | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | 2026-06-13 snapshot では `rails_table_preferences@main` が `ahead_by:964`, `behind_by:0`。2026-06-25 refresh では #1650 known-good baseline gate を先に解く | `b3f1a9d6eb46aefe568c637396fab63151aef322` |

Notes:

- #858 still records older pins, including `tree_view` at `9c538f9...` and `rails_fields_kit` at `b1a4b1c...`; do not use those values for new bump planning.
- #2983 / PR #3019 updated `tree_view` from `9c538f9ee7946fa5af24f15c99402a0431677303` to `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` and kept RFK / RTP unchanged.
- Future bump PRs must update the lockfile with Bundler when a checkout is available, or clearly document connector-only limitations and rely on PR CI for bundle/install confirmation.
- The ahead counts are directional planning signals. Re-measure immediately before opening a bump PR.

## First tranche candidate matrix

| gem | first tranche treatment | target ref candidate | upstream evidence | downstream smoke in docs-portal | exclusion / wait rule |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | Completed as the first concrete target in #2983 / PR #3019. Treat `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` as the current docs-portal baseline until a new TreeView lane is planned. | Completed target: `e129cb3ce2835a483e87fc71a50cc9fee07e3da5`. It replaced old pin `9c538f9ee7946fa5af24f15c99402a0431677303`. | #1645 is merged. PR #3019 re-measured `tree_view-rails@main` before the bump and recorded CI `ci #5599` success on docs-portal. 2026-06-25 refreshでは、TreeView #2583 merge は common policy evidence として扱い、new bump target にはしない。 | Sidebar tree expand / collapse, detail tree route context, current row, persisted state, and controller registration duplication avoidance. PR #3019 used `spec/requests/document_tree_regressions_spec.rb` through docs-portal CI as representative smoke. | Do not reopen TreeView first tranche as pending. New TreeView changes need a new issue with fresh upstream SHA, smoke, and rollback target. Visual / design lane は release train first tranche に混ぜない。 |
| `rails_fields_kit` | Wait for the helper export / public surface lane to be accepted, or explicitly stack only if a human approves a PR-head target. 2026-06-25 refreshでは #2102 / #2103 / #2129 などを古い green CI だけで target にしない。 | Prefer `rails_fields_kit@main` after the selected RFK public surface PRs are merged and fresh CI / compare freshness are rechecked. If stacking is approved, record the exact PR head as a non-main target. | #1485 was the 2026-06-13 candidate. #3796 / #3817 later shifted the review order toward newer RFK PRs, but public surface adoption still requires human review / fresh CI. | `admin/document_sets` form initial render, selected value preservation, invalid rerender, package-root controller registration, Vite alias, initializer, and no-op legacy shim. | Do not write open RFK PR behavior as current main fact. Do not combine helper-export family review or screen-by-screen RFK adoption with the bump PR. |
| `rails_table_preferences` | Keep the low-risk guard / stylesheet / known-good baseline lanes separated. 2026-06-25 refreshでは open PR がないため、feature target より #1650 の known-good SHA / representative CI evidence policy を先に決める。 | Candidate is not fixed in this document. Use a verified `rails_table_preferences@main` target only after #1650 or equivalent human baseline gate is resolved. | #1562 is merged and adds select filter option search empty/status guard. #1528 is open in the older snapshot and must not be treated as a resolved target without current metadata. | `admin/document_sets` editor + table with stable column keys, filter/preset behavior, mounted engine save, and select filter option search empty/status cue when that lane is included. | Exclude stylesheet export / package subpath decisions until mergeability and human review are resolved. Do not mix CSS subpath export, known-good baseline, and low-risk select filter guard lane. |

## Workflow and CI confirmation rule

Combined status can be empty for these repos even when GitHub Actions has run. For each target candidate, record all of the following before making a bump PR:

1. upstream repo and target SHA
2. PR metadata such as state, draft status, mergeability, merged state, and the exact confirmation time
3. workflow run name / number and result
4. compare freshness (`ahead_by`, `behind_by`, and `status`) for the target branch or PR head
5. `docs-portal` from SHA, to SHA, representative smoke, result, and rollback target

Do not treat an open PR head as a current-main target unless the PR body or Issue comment explicitly says the downstream PR is intentionally stacked. Do not treat CI success as visual approval, human public API approval, or current-main freshness.

## Recommended follow-up issue split

After #2962 and #2983, create or update small child Issues instead of reopening #858 as one large implementation unit.

| follow-up | suggested scope | dependency |
| --- | --- | --- |
| TreeView bump / smoke | Completed by #2983 / PR #3019. Use the completed row as historical evidence and do not create another TreeView first-tranche PR from the old `9c538f9...` premise. | New TreeView lanes require a fresh upstream target SHA, docs-portal representative smoke, and rollback target. |
| RFK public surface bump / smoke | Update only `rails_fields_kit` after selected RFK PRs are merged, refreshed, and accepted, then record `admin/document_sets` selected value / invalid rerender / wiring smoke and rollback. | Wait for merge or get explicit human approval for a PR-head stacked target, then re-measure mergeability and workflow status before opening the downstream bump PR. |
| RTP known-good baseline / smoke | Decide #1650 known-good SHA / representative CI evidence policy before treating RTP current main as a downstream target. | Keep public surface / stylesheet / package verifier policy decisions out until human gate is resolved. |
| RTP stylesheet export lane | Decide separately whether `rails_table_preferences/styles.css` subpath export belongs in the downstream target. | The stylesheet export lane must be mergeable / reviewed / intentionally selected before this lane is eligible. |

## Cross-link notes

- #858 remains the parent release train queue and is still too large for direct Fixer implementation.
- #2555 remains the package-root / package-entrypoint evidence-family discussion and should not be treated as this bump matrix's implementation issue.
- #2576 contains older representative PR facts. Use this document's current pin and PR-status snapshot when splitting new Fixer-sized work.
- #2983 / PR #3019 are the source of truth for the completed TreeView first tranche and its rollback target.
- #3796 and #3817 are the 2026-06-24 / 2026-06-25 cross-repo sequencing hubs. Prefer their latest comments over the older queue snapshot when deciding review order.

## Bump execution stop conditions

- GitHub checkout / fetch ができず、target SHA を作業直前に再計測できない
- Bundler を実行できず、`Gemfile.lock` を正しく再生成できない
- representative smoke を実行または確認できず、PR 本文に結果を残せない
- `#1650` のような human gate が残っている revision を、人間判断なしに target として扱う必要がある
- open upstream PR / proposal を current support として書く必要がある
- 古い green CI、behind / diverged branch、未提出 browser-capable evidence を readiness として使う必要がある
- 複数 gem の同時 bump、UI redesign、DB / auth / external API、business spec 判断が必要になる

この条件に当たる場合、Docs Sync Agent / Fixer は `Gemfile` や `Gemfile.lock` を connector で手編集せず、対象 issue に停止理由と再開条件を残します。
