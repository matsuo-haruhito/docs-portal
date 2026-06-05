# internal UI gem release train snapshot (2026-06-05 JST)

この snapshot は、`docs-portal#858` 配下の internal UI gem release train を読むための時点メモです。

`docs/internal-ui-gem-release-train-current-queue.md` と `docs/internal-ui-gem-upstream-readiness-snapshot.md` の古い 2026-06-03 / 2026-06-04 snapshot を削除せず、2026-06-05 23:00 JST 時点で再確認した current pins、upstream distance、open PR の扱いだけを追加で整理します。

この文書では target SHA を決めません。`Gemfile` / `Gemfile.lock` も変更しません。dependency bump を実行する PR では、作業直前に upstream `main`、candidate PR、CI、mergeability、`docs/internal-gem-release-train-smoke.md` の representative smoke を再確認します。

## 判定分類

- `docs-sync`
- `docs-stale`
- `docs-ahead-of-code` 回避: open upstream PR を current support として先取りしない

## docs-portal current pins

`Gemfile` の 2026-06-05 23:00 JST 時点の current pin は次のとおりです。

| gem | docs-portal current ref | upstream main distance | release train での扱い |
| --- | --- | --- | --- |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | upstream `main` is 407 commits ahead / 0 behind | `#1300` の single pinned-ref bump lane。target SHA はこの snapshot では決めない |
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | upstream `main` is 582 commits ahead / 0 behind | `#1301` の single pinned-ref bump lane。TreeView public surface / docs entrypoint evidence は merge 後に再確認する |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | upstream `main` is 670 commits ahead / 0 behind | `#789` の known-good revision / smoke scope human gate を維持する |

距離は current pin と upstream `main` の比較結果です。commits ahead が大きいことは bump すべき target SHA を意味しません。known-good revision、lockfile regeneration、representative smoke、rollback target は別 PR / 別判断で扱います。

## 2026-06-05 representative PR state

| repo | PR | 2026-06-05 23:00 JST status | release train での読み方 |
| --- | --- | --- | --- |
| `rails_fields_kit` | `#1068` | closed / not merged。clean replacement `#1073` へ置き換え済み | 2026-06-05 21:48 JST 時点の open green example としては古い。RFK release-facing docs sync は replacement 側で再確認する |
| `rails_fields_kit` | `#1069` | closed / not merged。support boundary wording refresh は別 replacement / queue 側で扱う | closed PR を current upstream support として読まない |
| `rails_table_preferences` | `#1029` | closed / not merged。helper-free table root manual QA checklist の current-main replacement だったが閉じられている | RTP evidence として採用する場合は current open PR / merged docs を取り直す |
| `tree_view-rails` | `#1392` | open / mergeable true。breadcrumb default class boundary docs-only replacement | default class names を manifest-backed public styling contract として固定するかは human review に残す |
| `tree_view-rails` | `#1393` | open / mergeable true。state install generator setup contract replacement | public setup surface を manifest-backed contract に含める採否は human review に残す |
| `tree_view-rails` | `#1396` | open / mergeable true / CI #1734 success。`script/test_docs_entrypoints.mjs`, `app/javascript/tree_view/index.d.ts`, `spec/public_api_manifest_structure_spec.rb` の 3 files | TreeView public surface / docs entrypoint / TypeScript declaration / manifest expectation evidence を強めるが、merge 前は current support として書かない |
| `docs-portal` | `#2103` | open review-wait lane | Git同期履歴 status cue の UI/review lane。internal UI gem bump evidence とは混ぜない |
| `docs-portal` | `#2091` | open review-wait lane | 生成ファイル実行履歴 detail masking の security-adjacent lane。release train target 判断とは混ぜない |

## priority / gate

1. `matsuo-haruhito/rails_table_preferences#678` は RTP package-root JS export / docs smoke guard として、`docs-portal#789` の human gate と分けて読む。
2. `docs-portal#1300` は RFK single pinned-ref bump lane。作業直前の upstream main、lockfile regeneration、`admin/document_sets` representative smoke が必要。
3. `docs-portal#1301` は TreeView single pinned-ref bump lane。`#1392` / `#1393` / `#1396` のような open green PR は、merge 後に再確認する候補として読む。
4. `docs-portal#789` は RTP known-good revision / smoke scope の human gate を維持する。
5. `matsuo-haruhito/tree_view-rails#413` は TreeView lockfile / `npm ci` reproducibility foundation として別に確認する。

## boundaries

- `#1886` は 2026-06-03 時点の upstream green PR snapshot として completed。今回の 2026-06-05 snapshot はその置き換えではなく、後続の追補です。
- open PR、CI success、mergeable true、merged は同じ readiness ではありません。
- open PR は `merge 後に再確認`、`branch refresh attention`、`human review` として扱い、docs-portal の current support として先取りしません。
- target SHA、Gemfile bump、Gemfile.lock 更新、runtime smoke 成功、representative smoke 成功宣言はこの docs-only snapshot の対象外です。
- 複数 gem の同時 bump、upstream PR の review / merge 判断、CI fix、branch refresh 実装は行いません。

## next handoff

- `docs/internal-ui-gem-release-train-current-queue.md` は引き続き current queue の入口として読む。
- この snapshot は 2026-06-05 23:00 JST の追加確認メモとして、bump PR / Planner / reviewer が古い open PR 状態と current distance を混同しないために参照する。
- bump 実行時は、この snapshot の数値や PR 状態をそのまま使わず、作業直前に再計測する。
