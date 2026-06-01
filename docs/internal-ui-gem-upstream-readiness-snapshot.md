# Internal UI gem upstream readiness snapshot

この snapshot は、`docs-portal` の internal UI gem release train (`#858` family) で `rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の pinned ref を動かす前に、上流 PR を待つか待たないかを確認するための時点メモです。

- Snapshot time: 2026-06-02 04:00 JST scheduled run
- 対応 Issue: `#1616`
- 判定分類: `docs-sync`, `docs-stale`
- 対象外: `Gemfile` / `Gemfile.lock` 更新、target SHA の最終決定、上流 PR review、smoke 実行

この文書は target SHA を決めません。実際の bump PR では、作業直前に current `Gemfile` / `Gemfile.lock`、上流 `main`、候補 PR の CI / mergeability、代表 smoke を再確認してください。

## docs-portal 側の読み分け

| docs-portal item | 2026-06-02 04:00 JST status | release train 前の扱い |
| --- | --- | --- |
| `#1620` / `#1552` current queue docs | PR open。`main...docs/1552-internal-ui-release-train-queue` は `ahead_by: 2`, `behind_by: 0`。`docs-quality` #503 と `ci` #3670 は success | current queue の整理 PR。merge されるまでは、この snapshot から未マージ文書への必須リンクは置かない |
| `#1510` / `#1470` state cue inventory | PR open。`main...design/1470-internal-ui-state-cue-inventory` は `ahead_by: 2`, `behind_by: 32`。Reviewer / Workflow Manager は human review / branch refresh 待ちとして扱っている | state cue / wording / ownership boundary の判断材料。release train の target SHA 判断へ自動で含めない |
| `#1300` / `#1301` / `#789` dependency bump lane | Planner 済みだが、checkout + Bundler lockfile regeneration + representative smoke が必要 | Docs Sync Agent は target SHA を決めない。bump 実行者がこの snapshot と上流の最新状態を見て 1 gem ずつ判断する |

## upstream PR readiness

| upstream repo | PR | current status | release train target への扱い |
| --- | --- | --- | --- |
| `rails_fields_kit` | `#730` package exports smoke section boundary | merged 2026-06-01。runtime public API / package exports は未変更 | 次の RFK candidate に含めてよい representative docs / smoke signal |
| `rails_fields_kit` | `#630` results wrapper controller helper docs | open, `mergeable: true`, docs-only | RFK docs surface の改善。target SHA に必須ではないが、remote search / selected preload docs を読むなら merge 状態を再確認する |
| `rails_fields_kit` | `#570` table metadata `group_html:` wrapper option | open, `mergeable: true`, public helper option追加 | `docs-portal` の current representative smoke には必須ではない。host app が group wrapper option を使う判断が出るまで human review 待ち |
| `tree_view-rails` | `#1058` persisted-state troubleshooting | merged 2026-06-01。runtime behavior は未変更 | 次の TreeView candidate に含めてよい docs signal |
| `tree_view-rails` | `#1039` selection hidden input docs / mockup boundary | open, `mergeable: false`, docs-only | selection docs の整理。sidebar / detail tree bump の必須条件にはしない。merge されるまで target SHA に含める判断を急がない |
| `tree_view-rails` | `#908` selection data hook package-root export | open, `mergeable: false`, public JavaScript export追加 | public API 追加のため human review 待ち。docs-portal の tree smoke へ自動で含めない |
| `rails_table_preferences` | `#685` export docs / quick start sync | merged 2026-06-01。runtime behavior は未変更 | 次の RTP candidate に含めてよい docs signal |
| `rails_table_preferences` | `#683` flat `resource_table_for` scroll wrapper option | open, `mergeable: true`, public helper option追加 | `docs-portal` が horizontal overflow wrapper を採用する scope でなければ必須ではない。RTP bump target に含めるかは human review / smoke 前に再確認する |
| `rails_table_preferences` | `#631` filter panel accessibility boundary | open, `mergeable: true`, UI accessibility surface | bundled filter panel の accessibility判断を含む。state cue / UX review と合わせて human review 待ち |
| `rails_table_preferences` | `#612` show-all-columns editor action | open, `mergeable: false`, editor action追加 | bundled editor action の public behavior 追加。known-good revision 判断が必要で、`#789` の human gate を越えて自動で含めない |

## target SHA 判断の前に見る順序

1. `docs/internal-gem-release-train-smoke.md` で対象 gem、current pin、代表 smoke、rollback target を確認する。
2. この snapshot で上流 PR を `merged / open mergeable / open human-gated / not required` に分ける。
3. 対象 gem の上流 `main` と候補 PR を作業直前に再確認する。ここにある `mergeable` は時点依存として扱う。
4. 1 gem だけ選び、Bundler で `Gemfile.lock` を再生成する。SHA 行だけの手編集で代替しない。
5. representative smoke を実行し、PR 本文または issue comment に `from`, `to`, smoke surface, result, rollback target を 1 箇所へ残す。

## stop / human review conditions

- 上流 PR が public API、helper signature、bundled UI behavior、selection / editor / filter semantics を変える場合
- candidate target に open `mergeable: false` PR を含める必要がある場合
- `#1510` state cue inventory の wording / ownership boundary を前提にしないと判断できない場合
- `#789` の known-good revision を先取りする必要がある場合
- checkout、Bundler、representative smoke を安全に実行できない場合

これらに当たる場合は dependency bump PR を作らず、対象 child issue に最後に確認した current pin、候補 target、止まった理由、再開条件を短く残します。
