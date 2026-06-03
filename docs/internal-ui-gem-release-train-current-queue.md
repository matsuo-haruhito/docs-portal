# internal UI gem release train current queue

この文書は、`docs/関連gem連携調査runbook.md` の release train 説明を読む前に確認する current queue snapshot です。

`docs-portal` の internal UI gem 更新は `#858` を parent / hub として扱います。実際の dependency bump は、ここにある current child issue と `docs/internal-gem-release-train-smoke.md` の代表 smoke / rollback note を合わせて確認します。

## current queue (2026-06-03 JST)

| 順序 | gem | current docs-portal ref | current child / gate | 扱い |
| --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `#1300` | 先行 bump 候補。setup doctor、package-root helper export、JS smoke inventory、public API docs guard の upstream evidence を確認し、Planner が target SHA / merge 済み PR / representative smoke を確定してから bump PR に進める |
| 2 | `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `#1301` | manifest-backed public surface の進行状況を確認し、sidebar tree / detail tree / persisted state smoke と upstream manifest / release evidence を分けて記録する |
| human-gated | `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `#789` | known-good target revision の人間判断待ち。package entrypoint、copied controller 差分、release checklist、compatibility matrix、demo / manual QA の upstream evidence は読むが、human gate 前に broad bump や downstream canary を混ぜない |

## 横断 evidence の現在地

- `rails_fields_kit` は、3 gem の中で `docs-portal#1300` の単独 bump 候補として最初に見る。target SHA はこの文書で決めず、Planner / 実行 PR 側で merge 済み upstream PR と representative smoke を再確認する。
- `rails_table_preferences` は、`docs-portal#789` の known-good revision 判断が gate のまま。upstream docs / package evidence が増えていても、human decision 前に current support として broad bump 予定を書かない。
- `tree_view` は、manifest-backed public surface と docs-portal 側の sidebar / detail tree smoke を分けて扱う。upstream manifest / public API の進行中 PR や proposal を current support として先取りしない。
- 3 gem 共通で、upstream evidence と downstream smoke は同じ PR body に混ぜてよいが、責務は分けて記録する。upstream docs の完了は host app smoke の成功を意味しない。

## 関連 issue の読み分け

- `#858`: release train の parent / hub。実装や docs 更新の最小単位ではない。
- `#1801`: この current queue と横断 evidence docs の優先順位を、open proposal を current support にしない範囲で更新する docs-sync issue。
- `#1845`: PR 種別別の evidence template を再利用できるようにする docs-sync issue。target SHA や bump 実行は決めない。
- `#1509`: 完了済み。`docs/internal-ui-gem-public-surface-package-verification-matrix.md` を追加した matrix issue として参照する。
- `#1470`: state cue inventory の parallel design lane。dependency bump、target SHA、Gemfile / lockfile 更新とは混ぜない。
- `#1552`: この current queue を `docs/関連gem連携調査runbook.md` から誤読しないための docs sync issue。
- `#1616`: release train 前に見る upstream PR readiness snapshot。target SHA の最終決定ではなく、open / merged upstream PR を docs-only、public API / helper、UI behavior、stacked PR に分ける入口として読む。

## update log で分ける項目

PR body、issue comment、review follow-up comment のいずれか 1 箇所に、次の 2 系統を分けて残します。

```text
- upstream evidence:
  - merged PR / docs path / package guard / manifest / release checklist
- downstream docs-portal smoke:
  - host app surface / request or system spec / manual evidence / rollback target
```

`upstream evidence` に open PR や proposal が含まれる場合は、`current support` ではなく `確認待ち` または `merge 後に再確認` として書きます。

## PR 種別別 evidence template

release train まわりの PR では、PR 種別ごとに必要な evidence を同じ粒度で残します。ここでいう evidence は「bump してよい」と決める材料ではなく、reviewer が upstream と downstream の責務を分けて確認するための記録です。

| PR 種別 | upstream evidence に残す最小欄 | downstream docs-portal smoke に残す最小欄 | 停止条件 / 書かないこと |
| --- | --- | --- | --- |
| `docs-only` | 参照した upstream docs path、merged PR、release checklist。open proposal は `確認待ち` として分ける | 更新した docs-portal docs、current code / issue / PR との照合結果、docs-quality 結果 | target SHA、Gemfile bump、runtime smoke 成功を docs-only PR で断定しない |
| `runtime helper` | public API docs、helper / option の source of truth、package guard または release checklist | host app の代表 view / helper / request spec、rollback 先、manual evidence の有無 | host app の params、authorization、business copy を upstream gem の責務にしない |
| `JavaScript package entrypoint` | package root / direct entrypoint、exports map、JS smoke / package verifier、importmap fallback | `app/frontend/entrypoints/application.js`、`vite.config.ts`、代表 controller / field smoke | direct entrypoint fallback を default contract に昇格させる場合は人間判断へ戻す |
| `public API manifest` | manifest / public API inventory、docs drift guard、built gem / package contents guard | manifest-backed surface が docs-portal で使われる view / spec / manual evidence | manifest にない open PR / proposal hook を current support として書かない |
| `host-app bump` | from / to SHA、merged upstream PR、public docs / package evidence、known-good revision gate | representative smoke、CI / docs-quality、rollback target、未確認 surface | Bundler を実行できない、target SHA を再計測できない、human gate が残る場合は bump しない |

connector-only で browser screenshot を取得できない場合は、代替 evidence を次のいずれかとして明記します。

- source spec / request spec / system spec で固定した表示境界
- static visual reference / mockup / review gallery の current path
- PR 本文上の表示証跡と未取得 screenshot の理由
- manual QA が必要な viewport / 操作 / expected cue

代替 evidence は screenshot の完全な置き換えではありません。reviewer が screenshot、manual QA、browser smoke を求めている場合は、Docs Sync Agent が current docs に「確認済み」と書かず、`needs-human` または `manual evidence pending` として残します。

## historical / old child numbers

`docs/関連gem連携調査runbook.md` に残る `#921`、`#903`、`#904` は historical context として読みます。current active lane として扱う場合は、必ず上の `#1300`、`#1301`、`#789` と `docs/internal-gem-release-train-smoke.md` を再確認します。

## bump 実行前の停止条件

- GitHub checkout / fetch ができず、target SHA を作業直前に再計測できない
- Bundler を実行できず、`Gemfile.lock` を正しく再生成できない
- representative smoke を実行または確認できず、PR 本文に結果を残せない
- `#789` のような human gate が残っている revision を、人間判断なしに target として扱う必要がある
- open upstream PR / proposal を current support として書く必要がある
- 複数 gem の同時 bump、UI redesign、DB / auth / external API、business spec 判断が必要になる

この条件に当たる場合、Docs Sync Agent / Fixer は `Gemfile` や `Gemfile.lock` を connector で手編集せず、対象 issue に停止理由と再開条件を残します。

## 先に見る docs

- `docs/internal-ui-gem-upstream-readiness-snapshot.md`: release train 前に確認する upstream open / recently merged PR の時点 snapshot。target SHA 決定ではなく、再確認対象と human gate を分ける入口
- `docs/internal-gem-release-train-smoke.md`: human handoff、representative smoke、rollback target、update log template
- `docs/internal-ui-gem-public-surface-package-verification-matrix.md`: package-root export、direct entrypoint、manifest / package verification の境界
- `docs/internal-ui-gem-adoption-evidence-map.md`: docs-portal 側 representative smoke、upstream evidence、確認順、rollback note
- `docs/internal-ui-gem-public-surface-guard-playbook.md`: public surface、docs drift guard、package evidence、downstream smoke の比較入口
- `docs/関連gem連携調査runbook.md`: host app 採用パターン、screen-by-screen adoption、upstream docs 入口
