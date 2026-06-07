# internal UI gem cross-repo queue order

この文書は、`#858` / `#607` / `#789` と upstream 3 gem の open gate を、2026-06 時点の docs-only queue として読み分けるための短い補助メモです。

`docs/internal-ui-gem-adoption-evidence-map.md`、`docs/internal-ui-gem-release-train-current-queue.md`、`docs/internal-ui-gem-release-train-readiness-matrix.md` を正本として読み、ここでは「どの順で見るか」と「どこで止めるか」だけを整理します。target SHA、known-good revision、Gemfile bump、upstream PR の merge 判断はこの文書では決めません。

## 2026-06 queue order

| 順序 | 対象 | 先に見る evidence | docs-portal 側の smoke / action | 現在の境界 |
| --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit` | setup / package advisory、package-root helper export、public API docs、visual reference。open upstream PR は merge 後に main で再確認する | `admin/document_sets` form の selected value、placeholder、invalid rerender、RFK remote picker の current wiring を確認する | `#1300` の単独 bump 候補。target SHA と lockfile 更新は runner-capable 環境で決める |
| 2 | `tree_view` | viewer tree docs、public manifest guard、package / installation guard、visual mockup evidence。open manifest PR は current support として書かない | sidebar tree、detail tree、persisted state、route context、window offset を downstream smoke として分ける | `#1301` は `#1300` 後に進める候補。manifest / node-shape policy は upstream 判断へ戻す |
| human-gated | `rails_table_preferences` | package-root controller export、documented direct entrypoint、release checklist、package verifier、manual QA docs | `admin/document_sets` の table preferences editor、stable column key、filter / preset、mounted save を representative smoke として残す | `#789` の known-good revision / Rails 8.1 host-app 判断待ち。human gate が解けるまで broad bump を先取りしない |

## Issue role boundaries

| Issue | 役割 | この docs queue での扱い |
| --- | --- | --- |
| `#858` | internal UI gem 3 本の pinned ref release train parent / hub | parent のまま扱う。3 gem bump 完了や target SHA 決定をこの Issue だけで宣言しない |
| `#607` | screen-by-screen host-app adoption pattern parent | `#858` の first slice と競合させない。ref 鮮度、representative smoke、rollback note の置き方が見えてから host-app 共通 pattern へ進める |
| `#789` | `rails_table_preferences` known-good revision / Rails 8.1 host-app 判断 gate | `needs-human` を維持する。package-root evidence と downstream smoke は読めても、known-good SHA は docs-only で決めない |
| `#1300` | `rails_fields_kit` 単独 bump child | first execution candidate。ただし Bundler / lockfile 再生成 / smoke が必要なため connector-only docs run では実装しない |
| `#1301` | `tree_view` bump child | `#1300` 後の候補。TreeView public manifest / visual evidence と docs-portal smoke を分けて記録する |

## Open gate handling

- open upstream PR、proposal、CI green / mergeable true は `current support` ではなく `merge 後に再確認` または `human gate` として扱います。
- upstream docs の完了は docs-portal 側 representative smoke の成功を意味しません。PR body や issue comment では `upstream evidence` と `downstream docs-portal smoke` を分けて残します。
- `#607` の host-app common pattern は、`#858` release train の first slice を待たずに広げると ref 鮮度判断を抱えやすいため、先に `#1300` / `#1301` / `#789` の gate を読みます。
- `Gemfile` / `Gemfile.lock`、runtime code、spec、CI workflow はこの docs queue では変更しません。

## Stop conditions

次のいずれかに当たる場合、Docs Sync Agent は docs-only PR で先取りせず、対象 Issue に停止理由と再開条件を残します。

- target SHA、known-good revision、upstream PR の採否を決める必要がある
- Bundler / lockfile 再生成や representative smoke の実行が必要になる
- open PR の内容を current main の実装済み behavior として書く必要がある
- host app の business spec、権限、DB、外部 API、UI redesign 判断が必要になる

## 関連 docs

- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md)
- [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md)
- [internal UI gem release train readiness matrix](./internal-ui-gem-release-train-readiness-matrix.md)
- [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md)
- [internal UI gem JS resolver matrix](./internal-ui-gem-js-resolver-matrix.md)
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md)
