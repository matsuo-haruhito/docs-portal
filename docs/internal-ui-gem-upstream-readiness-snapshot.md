# internal UI gem upstream readiness snapshot

この snapshot は、`docs-portal` の internal UI gem pinned ref を更新する前に、上流 3 gem の open / recently merged PR を横断確認するための時点メモです。

ここでは target SHA を決めません。`Gemfile` / `Gemfile.lock` も変更しません。dependency bump を実行する PR では、作業直前に upstream `main`、candidate PR、CI、mergeability、`docs/internal-gem-release-train-smoke.md` の representative smoke を再確認します。

## snapshot

- 確認日時: 2026-06-02 05:00 JST scheduled run
- 判定分類: `docs-missing` / `docs-sync`
- 対応 Issue: `#1616`
- release train queue: `#1300` (`rails_fields_kit`) -> `#1301` (`tree_view`) -> `#789` (`rails_table_preferences`, human-gated)
- 関連 docs: `docs/internal-ui-gem-release-train-current-queue.md`, `docs/internal-gem-release-train-smoke.md`, `docs/internal-ui-gem-public-surface-package-verification-matrix.md`

## docs-portal side

| item | 2026-06-02 JST status | release train での扱い |
| --- | --- | --- |
| `docs-portal#1510` | open / mergeable true | state cue inventory の parallel design lane。dependency bump、target SHA、Gemfile / lockfile 更新とは混ぜない |
| `docs-portal#1552` | completed | current queue 同期は完了済み。この snapshot は `#1552` の置き換えではなく、upstream PR readiness の追加メモとして読む |
| `docs-portal#1300` | needs-human 相当 | `rails_fields_kit` bump は checkout、Bundler lockfile regeneration、representative smoke が揃う環境でだけ進める |
| `docs-portal#1301` | needs-human 相当 | `tree_view` bump は `#1300` の扱い確認後に進め、sidebar tree / detail tree / persisted state smoke を分けて記録する |
| `docs-portal#789` | human-gated | `rails_table_preferences` の known-good target revision は自動で決めない |

## rails_fields_kit

| PR | 2026-06-02 JST status | target SHA 判断での読み方 |
| --- | --- | --- |
| `rails_fields_kit#730` | merged | package export smoke の section boundary は upstream `main` 側の再計測対象。bump 実行時に current upstream main に含まれる前提で diff / smoke を取り直す |
| `rails_fields_kit#630` | open / mergeable true | docs-only response shape 同期。merge 済みなら docs diff として含めてよいが、runtime target SHA の必須 blocker にはしない |
| `rails_fields_kit#570` | open / mergeable true | FormBuilder helper public surface の additive option。docs-portal `#1300` に含めるかは human target 判断と representative smoke 次第 |

`rails_fields_kit` では、open docs-only PR と public helper surface PR を分ける。`#630` は docs drift 解消、`#570` は public helper option 追加なので、同じ「mergeable true」として扱わない。

## tree_view

| PR | 2026-06-02 JST status | target SHA 判断での読み方 |
| --- | --- | --- |
| `tree_view-rails#1058` | merged | persisted-state troubleshooting docs は upstream `main` 側の再計測対象。bump 実行時に docs diff として含まれる可能性が高い |
| `tree_view-rails#1039` | open / mergeable false | selection hidden input docs / mockup boundary の docs-only PR。mergeability が戻るまで target SHA の前提にしない |
| `tree_view-rails#908` | open / mergeable false | selection data hook の package-root public export。`docs-portal#1301` に含めるかは public API / manifest / entrypoint smoke の human review 待ち |

`tree_view` では docs-only の `#1039` と public export の `#908` を混ぜない。`#908` を含める場合は、docs-portal 側の import path、manifest expectation、selection form smoke が必要になる。

## rails_table_preferences

| PR | 2026-06-02 JST status | target SHA 判断での読み方 |
| --- | --- | --- |
| `rails_table_preferences#685` | merged | export / quick start / changelog docs は upstream `main` 側の再計測対象 |
| `rails_table_preferences#683` | open / mergeable true | flat `resource_table_for` の default-off scroll wrapper。public helper option 追加なので、`#789` human gate 前に自動で含めない |
| `rails_table_preferences#695` | open / mergeable true, base is `#683` branch | TreeView resource table wrapper follow-up。`#683` が main に入った後に retarget / fresh CI が必要な stacked PR として扱う |
| `rails_table_preferences#631` | open / mergeable true | filter panel accessibility boundary。UI/accessibility public surface のため、target SHA に含めるかは human review と smoke 次第 |
| `rails_table_preferences#612` | open / mergeable false | show-all-columns editor action。mergeability が戻るまで known-good target の前提にしない |

`rails_table_preferences` では `#683` / `#695` が wrapper option family、`#631` が accessibility boundary、`#612` が editor action で、いずれも docs-only ではない。`#789` の human gate が解消するまで、これらをまとめて current target と断定しない。

## bump 実行前チェック

1. `Gemfile` / `Gemfile.lock` の current pin が `docs/internal-ui-gem-release-train-current-queue.md` と一致するか確認する。
2. 対象 gem だけを選び、upstream `main` と candidate PR の最新 CI / mergeability / merged 状態を確認する。
3. recently merged PR は upstream main diff として再計測する。open PR は、docs-only、public helper/API、UI behavior、stacked PR に分類する。
4. target SHA を決める場合は、`docs/internal-gem-release-train-smoke.md` の representative smoke と rollback target を PR 本文または issue comment に 1 箇所だけ記録する。
5. checkout、Bundler lockfile regeneration、representative smoke ができない環境では、`Gemfile.lock` の SHA 行だけを手編集しない。

## boundaries

- この snapshot は release train target SHA の決定ではない。
- upstream PR のレビュー、merge、CI rerun、branch refresh はこの docs では行わない。
- docs-only PR と public API / helper / UI behavior PR を同じリスクとして扱わない。
- open PR の mergeability は時点依存なので、次回 scheduled run や bump 実行直前に必ず再確認する。
- `#1510` の state cue inventory、`#1552` の current queue、上流 readiness snapshot、dependency bump PR を 1 つの PR に混ぜない。
