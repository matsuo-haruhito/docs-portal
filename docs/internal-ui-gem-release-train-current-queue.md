# internal UI gem release train current queue

この文書は、`docs/関連gem連携調査runbook.md` の release train 説明を読む前に確認する queue snapshot です。

`docs-portal` の internal UI gem 更新は `#858` を parent / hub として扱います。実際の dependency bump は、ここにある child issue と `docs/internal-gem-release-train-smoke.md` の代表 smoke / rollback note を合わせて確認します。

2026-06-25 JST 時点の採用順・review gate・known-good baseline は、[internal UI gem release train target matrix](./internal-ui-gem-release-train-target-matrix.md) の `2026-06-25 cross-repo refresh` を優先して確認します。この文書の `2026-06-03 JST` queue は historical snapshot であり、open PR、old child issue、古い green CI を current adoption evidence として固定するものではありません。

## historical queue (2026-06-03 JST)

| 順序 | gem | current docs-portal ref | current child / gate | 扱い |
| --- | --- | --- | --- |
| 1 | `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `#1300` | 先行 bump 候補。setup doctor、package-root helper export、JS smoke inventory、public API docs guard の upstream evidence を確認し、Planner が target SHA / merge 済み PR / representative smoke を確定してから bump PR に進める |
| 2 | `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `#1301` | manifest-backed public surface の進行状況を確認し、sidebar tree / detail tree / persisted state smoke と upstream manifest / release evidence を分けて記録する |
| human-gated | `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `#789` | known-good target revision の人間判断待ち。README / `docs/index.md` family、`docs/javascript_entrypoints.md`、release checklist、package verifier、manual QA の upstream evidence を読むが、package entrypoint / copied controller / public JS surface / helper option surface の結論を docs-portal 側で決めない。`#1860` で更新した evidence map に沿って、table key / stable column key / filter-sort mapping / preset behavior / rollback target は downstream smoke として別に残す |

## 2026-06-04 evidence family intake

`#1960` では、2026-06-04 15:55 JST 時点の upstream evidence を、bump target 決定ではなく release train 前に読む gate family として整理します。upstream 正本は各 gem repo の PR / docs を参照し、この文書では `merged`、`open green`、`needs-human`、`ready-for-agent` の読み分けだけを残します。

| gem | evidence family | 2026-06-04 時点の読み方 | `docs-portal` release train での使い方 |
| --- | --- | --- | --- |
| `rails_fields_kit` | README Docs map / package contents guard (`rails_fields_kit#983`) | merged upstream evidence。README 入口と packaged maintained docs の drift guard として読める | `#1300` の target SHA 判断前に、package contents / docs reachability guard が upstream main に入っているか再確認する |
| `rails_fields_kit` | setup doctor (`rails_fields_kit#810`) | open green / mergeable。host app setup verification surface の候補だが current support ではない | merge 後に `doc/setup.md` / generated setup note / package inventory を再確認する。open の間は `manual evidence pending` または `merge 後に再確認` と記録する |
| `rails_fields_kit` | Tom Select request contract reader (`rails_fields_kit#980`) | open green / needs-human evidence。public package-root helper 追加を含む | host app bump evidence に含める場合は public helper/API と `admin/document_sets` smoke を分け、open PR を current support として書かない |
| `tree_view` | installation docs / package guard / CSS・importmap signal (`tree_view-rails#1280`) | merged upstream evidence。package / installation drift guard として読める | `#1301` の target SHA 判断前に、packaged CSS / JavaScript / importmap pin signal と docs drift guard が upstream main に入っているか再確認する |
| `tree_view` | PathTreeBuilder node-shape manifest (`tree_view-rails#1282`) | open green / needs-human evidence。public contract を強める候補 | manifest-backed surface と docs-portal sidebar / detail tree smoke を分け、merge 前に current support として書かない |
| `rails_table_preferences` | data-controller merge contract (`rails_table_preferences#917`) | merged upstream evidence。host app controller token と gem controller token の coexistence guard として読める | table helper adoption や copied controller 差分を確認するときの upstream guard として参照し、host app route / table key / business column は downstream evidence に分ける |
| `rails_table_preferences` | Turbo reconnect smoke matrix (`rails_table_preferences#915`) | merged upstream docs evidence。Turbo navigation / Frame replacement 後の editor + table contract の QA gate として読める | downstream canary ではなく upstream manual QA boundary として扱う。docs-portal 側で Turbo reconnect を確認したかは別途 smoke に残す |
| `rails_table_preferences` | resize handle keyboard auto-fit boundary (`rails_table_preferences#922`) | open green / needs-human evidence。package entrypoint の accessibility boundary を docs / QA に同期する候補 | open の間は review/merge input として扱う。full keyboard resizing や copied controller behavior を docs-portal current support として先取りしない |
| `rails_table_preferences` | RFK 連携向け renderer registry docs (`rails_table_preferences#910`) | ready-for-agent evidence。screen-by-screen 重複削減に効く docs example 候補 | merged までは docs-portal の current support として書かず、`#607` の adoption pattern では upstream ready lane として参照する |

## 横断優先度 scorecard (2026-06-04 JST)

`#1996` では、4 repo 横断で「次にどの evidence を見ると downstream に効くか」を比較します。この scorecard は target SHA、Gemfile bump、PR merge 判断を決める場所ではありません。`docs-portal` 側の release train reviewer が、上流正本 docs を重複転載せずに次の確認順をそろえるための小さな索引です。

| 優先 | repo / lane | downstream への波及度 | public surface guard の成熟度 | docs / visual evidence の再利用性 | host app representative smoke | 残り gate / risk | 次に見るもの |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `docs-portal` release train docs / representative smoke | 高。3 gem の採用 hub で、以後の bump / smoke / rollback note の読み方を決める | 中。`docs/internal-ui-gem-adoption-evidence-map.md` とこの current queue が正本 | 高。ROADMAP、evidence map、current queue、smoke runbook を同じ粒度で参照できる | あり。`admin/document_sets`、sidebar tree / detail tree、RTP representative screens | 低。docs-only だが open PR を current support として書かない | `#1987` / PR `#1994`、`#1986` / PR `#1995`、この scorecard |
| 2 | `rails_fields_kit` public API / field metadata helper family | 高。form helper / Tom Select wiring が host app の入力補助に直結する | 高。`doc/public_api.md`、package export smoke、visual reference、README docs map が揃いつつある | 高。setup docs、field/controller helper docs、visual reference を host app smoke に転用しやすい | あり。`admin/document_sets` form、invalid rerender、selected value | 中。open green / needs-human の helper PR は merge 後に再確認 | `#1300`、`#1985`、upstream public API / package contents guard |
| 3 | `tree_view-rails` manifest-backed JS export / declaration follow-up | 高。docs-portal の文書ツリー UX に直接効く | 中-高。installation / package guard は merged、manifest-backed node-shape は open green / needs-human | 中。README / docs / mockup gallery は強いが manifest proposal は merge 前に先取りしない | あり。sidebar tree / detail tree / persisted state / window offset | 中。public manifest や selection contract の human gate を current support にしない | `#1301`、upstream installation / package guard、manifest-backed public surface PR |
| 4 | `rails_table_preferences` public surface / representative smoke | 高。一覧・embedded table・saved state に広く波及する | 中。data-controller merge contract と Turbo reconnect docs は merged、renderer registry docs は ready lane | 中-高。manual QA docs / demo / matrix はあるが host app table key は downstream 責務 | あり。`admin/document_sets`、`admin/documents` など代表一覧 | 高。`#789` の known-good revision human gate と public surface 方針確認が残る | `#789`、`#1860`、`#1986`、upstream registry / accessibility evidence |

優先順位は「先に merge すべき PR」ではなく、release train 上で先に読み合わせる evidence の順番です。特に `rails_table_preferences` は波及度が高い一方で human gate が残るため、representative smoke と public surface 方針を確認してから bump / host app 展開へ進めます。

## 横断 evidence の現在地

- `rails_fields_kit` は、3 gem の中で `docs-portal#1300` の単独 bump 候補として最初に見る。target SHA はこの文書で決めず、Planner / 実行 PR 側で merge 済み upstream PR と representative smoke を再確認する。
- `rails_table_preferences` は、`docs-portal#789` の known-good revision 判断が gate のまま。`rails_table_preferences#798` は README / docs family + package verifier を source-of-truth family として明文化する planned 方針だが、human decision 前に current support として broad bump 予定を書かない。
- `tree_view` は、manifest-backed public surface と docs-portal 側の sidebar / detail tree smoke を分けて扱う。upstream manifest / public API の進行中 PR や proposal を current support として先取りしない。
- 3 gem 共通で、upstream evidence と downstream smoke は同じ PR body に混ぜてよいが、責務は分けて記録する。upstream docs の完了は host app smoke の成功を意味しない。

## release train PR preflight (2026-06-06 JST)

`#2114` では、release train / upstream evidence snapshot / replacement PR を作る前に、4 repo 横断で同じ Issue や同じ file family を重複して扱っていないかを軽く確認します。これは target SHA、Gemfile bump、PR merge / close を決める手順ではありません。

| 観点 | 確認すること | release train での扱い |
| --- | --- | --- |
| close intent | open PR の `Closes #...`、`Refs #...`、`Supersedes #...` が同じ issue を指していないか見る | 同じ issue を close する候補が複数ある場合は、新規 replacement を作る前に current 候補へ一本化できるか確認する |
| changed files overlap | `docs-portal` の release train docs、上流 gem docs、package / manifest / smoke files が既存 open PR と重なっていないか見る | 同じ file family を触る場合は、古い branch content で latest main や sibling PR の docs を巻き戻さない |
| base freshness / mergeability | open PR が current `main` から behind / diverged か、`mergeable:false` か、CI success 後に main が進んでいないか見る | stale replacement を作る前に、既存 PR の latest head / compare / changed files を取り直す |
| latest CI evidence | `docs-quality`、`ci`、上流 repo の CI が latest head の結果か確認する | 古い green run を readiness として使わない。baseline failure は PR 個別差分と分けて issue / comment に残す |
| current support boundary | open PR、proposal、closed not merged PR を current support として書いていないか見る | open PR は `merge 後に再確認`、`branch refresh attention`、`human review` として扱う |

repo-local の棚卸しは `tree_view-rails#1401` や `rails_table_preferences#807` に戻します。この節では 4 repo の全 PR を詳細レビューせず、docs-portal の release train 入口で重複 close intent、file overlap、stale replacement、latest CI、current support の誤読だけを先に見ます。

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
