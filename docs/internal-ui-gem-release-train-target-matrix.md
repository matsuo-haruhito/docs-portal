# Internal UI gem release train target matrix

この文書は、`docs-portal` の internal UI gem 3本について、次の Gemfile bump / smoke Issue を切る前に見る current snapshot です。`docs/関連gem連携調査runbook.md` と `docs/internal-gem-release-train-smoke.md` は恒常的な運用正本、この文書は 2026-06-13 JST 時点の target ref / downstream smoke / rollback matrix として扱います。未merge upstream PR の mergeability は変動するため、表内の値は確認時点付きの snapshot とし、bump PR を作る直前に必ず再測定します。

## Scope

- 対応 Issue: #2962
- 対象 gem: `tree_view`, `rails_fields_kit`, `rails_table_preferences`
- この文書で行うこと: current pin、upstream PR 状態、first tranche 候補、除外または判断待ち PR、代表 smoke、rollback 記録場所を更新する
- この文書で行わないこと: `Gemfile` / `Gemfile.lock` の更新、3 gem 一括 bump、upstream PR code review、upstream merge 判断、browser visual evidence の一括取得

## Current docs-portal pin

`Gemfile` と `Gemfile.lock` の current resolved revision は次のとおりです。この表を #858 / #2576 の古い前提より優先します。

| gem | current resolved revision | upstream main compare at 2026-06-13 JST | rollback target |
| --- | --- | --- | --- |
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `tree_view-rails@main` is `ahead_by:1012`, `behind_by:0` | `9c538f9ee7946fa5af24f15c99402a0431677303` |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `rails_fields_kit@main` is `ahead_by:720`, `behind_by:0` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `rails_table_preferences@main` is `ahead_by:964`, `behind_by:0` | `b3f1a9d6eb46aefe568c637396fab63151aef322` |

Notes:

- #858 still records an older `rails_fields_kit` pin (`b1a4b1c...`); do not use that value for new bump planning.
- `Gemfile` / `Gemfile.lock` remain unchanged in #2962. Future bump PRs must update the lockfile with Bundler, not by editing only the SHA lines.
- The ahead counts are directional planning signals. Re-measure immediately before opening a bump PR.

## First tranche candidate matrix

| gem | first tranche treatment | target ref candidate | upstream evidence | downstream smoke in docs-portal | exclusion / wait rule |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | Include as the first concrete target candidate after RFK/RTP blockers are separated. | `tree_view-rails@main` after merged PR `matsuo-haruhito/tree_view-rails#1645`; last checked main SHA `90b3fd75c1dcfcd216260ae57d85da3954020ef9`. | #1645 is merged. It added `TreeViewControllerEntries` as a package-root export and kept controller behavior unchanged. | Sidebar tree expand / collapse, detail tree route context, current row, persisted state, and controller registration duplication avoidance. Use `spec/requests/document_tree_regressions_spec.rb` plus the sidebar/detail tree surfaces listed in `docs/internal-gem-release-train-smoke.md`. | Do not mix upstream public hook redesign, selection model changes, or broader tree UI changes into the bump PR. |
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

After #2962, create or update small child Issues instead of reopening #858 as one large implementation unit.

| follow-up | suggested scope | dependency |
| --- | --- | --- |
| TreeView bump / smoke | Update only `tree_view` from `9c538f9ee7946fa5af24f15c99402a0431677303` to a verified `tree_view-rails@main` target that includes #1645, then record sidebar/detail tree smoke and rollback. | Re-measure `tree_view-rails@main` and confirm no open public-hook human gate is being folded in. |
| RFK helper-export bump / smoke | Update only `rails_fields_kit` after #1485 is merged, then record `admin/document_sets` selected value / invalid rerender / wiring smoke and rollback. | Wait for #1485 merge or get explicit human approval for a PR-head stacked target, then re-measure mergeability and workflow status before opening the downstream bump PR. |
| RTP select filter guard bump / smoke | Update only `rails_table_preferences` to a verified main target that includes #1562, then record `admin/document_sets` editor/filter/preset and select option search guard smoke. | Keep #1528 out until it is mergeable and reviewed. |
| RTP stylesheet export lane | Decide separately whether `rails_table_preferences/styles.css` subpath export belongs in the downstream target. | #1528 must be mergeable or replaced before this lane is eligible. |

## Cross-link notes

- #858 remains the parent release train queue and is still too large for direct Fixer implementation.
- #2555 remains the package-root / package-entrypoint evidence-family discussion and should not be treated as this bump matrix's implementation issue.
- #2576 contains older representative PR facts. Use this document's current pin and PR-status snapshot when splitting new Fixer-sized work.
