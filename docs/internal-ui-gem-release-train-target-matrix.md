# Internal UI gem release train target matrix

この文書は、`docs-portal` の internal UI gem 3本について、次の Gemfile bump / smoke Issue を切る前に見る current snapshot です。`docs/関連gem連携調査runbook.md` と `docs/internal-gem-release-train-smoke.md` は恒常的な運用正本、この文書は 2026-06-13 JST 時点の target ref / downstream smoke / rollback matrix と、2026-06-13 に完了した TreeView first tranche の反映状況として扱います。未merge upstream PR の mergeability は変動するため、表内の値は確認時点付きの snapshot とし、bump PR を作る直前に必ず再測定します。

## Scope

- 対応 Issue: #2962、#2983
- 対象 gem: `tree_view`, `rails_fields_kit`, `rails_table_preferences`
- この文書で行うこと: current pin、upstream PR 状態、first tranche の完了 / 後続候補、除外または判断待ち PR、代表 smoke、rollback 記録場所を更新する
- この文書で行わないこと: `Gemfile` / `Gemfile.lock` の更新、3 gem 一括 bump、upstream PR code review、upstream merge 判断、browser visual evidence の一括取得

## Current docs-portal pin

`Gemfile` と `Gemfile.lock` の current resolved revision は次のとおりです。この表を #858 / #2576 の古い前提より優先します。

| gem | current resolved revision | upstream main compare / release train state | rollback target |
| --- | --- | --- | --- |
| `tree_view` | `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` | #2983 / PR #3019 で first tranche bump 済み。PR CI `ci #5599` は success。次の TreeView lane を切る場合は、その時点の `tree_view-rails@main` を再測定する | `9c538f9ee7946fa5af24f15c99402a0431677303` |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | 2026-06-13 snapshot では `rails_fields_kit@main` が `ahead_by:720`, `behind_by:0` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | 2026-06-13 snapshot では `rails_table_preferences@main` が `ahead_by:964`, `behind_by:0` | `b3f1a9d6eb46aefe568c637396fab63151aef322` |

Notes:

- #858 still records older pins, including `tree_view` at `9c538f9...` and `rails_fields_kit` at `b1a4b1c...`; do not use those values for new bump planning.
- #2983 / PR #3019 updated `tree_view` from `9c538f9ee7946fa5af24f15c99402a0431677303` to `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` and kept RFK / RTP unchanged.
- Future bump PRs must update the lockfile with Bundler when a checkout is available, or clearly document connector-only limitations and rely on PR CI for bundle/install confirmation.
- The ahead counts are directional planning signals. Re-measure immediately before opening a bump PR.

## First tranche candidate matrix

| gem | first tranche treatment | target ref candidate | upstream evidence | downstream smoke in docs-portal | exclusion / wait rule |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | Completed as the first concrete target in #2983 / PR #3019. Treat `e129cb3ce2835a483e87fc71a50cc9fee07e3da5` as the current docs-portal baseline until a new TreeView lane is planned. | Completed target: `e129cb3ce2835a483e87fc71a50cc9fee07e3da5`. It replaced old pin `9c538f9ee7946fa5af24f15c99402a0431677303`. | #1645 is merged. PR #3019 re-measured `tree_view-rails@main` before the bump and recorded CI `ci #5599` success on docs-portal. | Sidebar tree expand / collapse, detail tree route context, current row, persisted state, and controller registration duplication avoidance. PR #3019 used `spec/requests/document_tree_regressions_spec.rb` through docs-portal CI as representative smoke. | Do not reopen TreeView first tranche as pending. New TreeView changes need a new issue with fresh upstream SHA, smoke, and rollback target. |
| `rails_fields_kit` | Wait for the helper export lane to be accepted, or explicitly stack only if a human approves a PR-head target. | Prefer `rails_fields_kit@main` after `matsuo-haruhito/rails_fields_kit#1485` is merged. If stacking is approved, record PR head `9c6cf61f4c05e86222e842f325e1773fbf6b3d29` as a non-main target. | #1485 is open, non-draft, and rechecked as `mergeable:true` at 2026-06-13 17:12 JST; CI #1784 was success. It adds `readRenderedTomSelectInteractionConfig(element)` as an additive read-only helper. Re-measure mergeability immediately before treating it as a target, because this value can drift while the PR remains unmerged. | `admin/document_sets` form initial render, selected value preservation, invalid rerender, package-root controller registration, Vite alias, initializer, and no-op legacy shim. | Do not write the helper as current main fact until #1485 merges. Do not combine helper-export family review or screen-by-screen RFK adoption with the bump PR. |
| `rails_table_preferences` | Split into two lanes: low-risk behavior guard can be a candidate after merge; stylesheet export remains excluded. | Candidate: `rails_table_preferences@main` after merged PR `matsuo-haruhito/rails_table_preferences#1562`; last checked main SHA `f99bd1f0ff3552731d8dcfbbc1600ee43d49f95d`. | #1562 is merged and adds select filter option search empty/status guard. #1528 is open with `mergeable:false` and must not be treated as a resolved target. | `admin/document_sets` editor + table with stable column keys, filter/preset behavior, mounted engine save, and select filter option search empty/status cue when that lane is included. | Exclude #1528 (`rails_table_preferences/styles.css` package subpath export) from first tranche until mergeability and human review are resolved. Do not mix CSS subpath export with the low-risk select filter guard lane. |

## Workflow and CI confirmation rule

Combined status can be empty for these repos even when GitHub Actions has run. For each target candidate, record all of the following before making a bump PR:

1. upstream repo and target SHA
2. PR metadata such as state, draft status, mergeability, merged state, and the exact confirmation time
3. workflow run name / number and result
4. `docs-portal` from SHA, to SHA, representative smoke, result, and rollback target

Do not treat an open PR head as a current-main target unless the PR body or Issue comment explicitly says the downstream PR is intentionally stacked.

## Recommended follow-up issue split

After #2962 and #2983, create or update small child Issues instead of reopening #858 as one large implementation unit.

| follow-up | suggested scope | dependency |
| --- | --- | --- |
| TreeView bump / smoke | Completed by #2983 / PR #3019. Use the completed row as historical evidence and do not create another TreeView first-tranche PR from the old `9c538f9...` premise. | New TreeView lanes require a fresh upstream target SHA, docs-portal representative smoke, and rollback target. |
| RFK helper-export bump / smoke | Update only `rails_fields_kit` after #1485 is merged, then record `admin/document_sets` selected value / invalid rerender / wiring smoke and rollback. | Wait for #1485 merge or get explicit human approval for a PR-head stacked target, then re-measure mergeability and workflow status before opening the downstream bump PR. |
| RTP select filter guard bump / smoke | Update only `rails_table_preferences` to a verified main target that includes #1562, then record `admin/document_sets` editor/filter/preset and select option search guard smoke. | Keep #1528 out until it is mergeable and reviewed. |
| RTP stylesheet export lane | Decide separately whether `rails_table_preferences/styles.css` subpath export belongs in the downstream target. | #1528 must be mergeable or replaced before this lane is eligible. |

## Cross-link notes

- #858 remains the parent release train queue and is still too large for direct Fixer implementation.
- #2555 remains the package-root / package-entrypoint evidence-family discussion and should not be treated as this bump matrix's implementation issue.
- #2576 contains older representative PR facts. Use this document's current pin and PR-status snapshot when splitting new Fixer-sized work.
- #2983 / PR #3019 are the source of truth for the completed TreeView first tranche and its rollback target.