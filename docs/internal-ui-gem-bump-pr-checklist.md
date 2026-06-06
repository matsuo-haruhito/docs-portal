# internal UI gem bump PR checklist

この文書は、`tree_view` / `rails_fields_kit` / `rails_table_preferences` の pinned ref を docs-portal で更新する PR を切る直前に使う checklist です。

`docs/internal-ui-gem-release-train-readiness-matrix.md` は upstream readiness の入口、`docs/internal-gem-release-train-smoke.md` は representative smoke と rollback note の正本です。この checklist は、それらを二重管理せず、library 別 bump PR の実行単位と PR body evidence をそろえるためだけに使います。

## 共通方針

- 1 PR では 1 gem だけを bump する。
- `Gemfile` / `Gemfile.lock` を変更する前に、対象 gem の current pin、candidate target、open PR / issue gate、latest CI を再確認する。
- target SHA はこの checklist では決めない。作業直前の compare、upstream CI、review state、human gate を PR body または issue comment に残す。
- upstream の package verification、public API guard、visual reference guard は docs-portal で再実行しない。docs-portal では host-app integration smoke だけを見る。
- `Gemfile.lock` は Bundler の生成結果を正本にする。SHA 行だけの手編集で bump 完了扱いにしない。
- runtime UI redesign、business rule、authorization、DB schema、external API、Rails / Ruby / Node support policy は同じ PR に混ぜない。

## PR 前 checklist

- [ ] 対象 gem は 1 つだけに決めた。
- [ ] `docs/internal-ui-gem-release-train-readiness-matrix.md` で package-root / direct entrypoint / resolver / public API guard の現状を確認した。
- [ ] `docs/internal-gem-release-train-smoke.md` で representative smoke と rollback target の置き場所を確認した。
- [ ] open upstream PR / issue を current support として書かず、`merge 後に再確認`、`human gate`、`ready follow-up` のいずれかに分けた。
- [ ] candidate target の CI / mergeability / release note を作業直前に確認した。
- [ ] Bundler で `Gemfile.lock` を再生成できる環境で作業している。
- [ ] smoke failure が出た場合に、host app 側の小さな修正で閉じるか、upstream / human gate へ戻すかを切り分ける準備がある。

## Library 別 smoke

| gem | bump PR の第一候補 issue | host-app smoke | PR body に残す evidence | rollback note |
| --- | --- | --- | --- | --- |
| `rails_fields_kit` | `#1300` | `admin/document_sets` form。initial render、selected value、invalid rerender、Tom Select wiring、Vite alias / initializer / no-op shim の責務境界を見る | from / to SHA、`admin_document_sets` request spec または manual smoke、open helper/export gate の扱い | current pin `0c29bb935a1df3e61add860a966a2fc7ea586b1a` へ戻す |
| `tree_view` | `#1301` | sidebar tree と detail tree。route context、persisted state、Turbo Stream refresh、window offset regression を見る | from / to SHA、`document_tree_regressions` などの request spec、manual tree smoke、upstream manifest/docs gate の扱い | current pin `9c538f9ee7946fa5af24f15c99402a0431677303` へ戻す |
| `rails_table_preferences` | `#789` human gate 後 | `admin/document_sets` index。table preferences editor、stable column key、filter / preset、mounted engine save、async failure / busy recovery 観点を見る | from / to SHA、table preference request spec または manual smoke、known-good revision 判断と unresolved gate | current pin `b3f1a9d6eb46aefe568c637396fab63151aef322` へ戻す |

`rails_fields_kit` と `rails_table_preferences` は同じ `admin/document_sets` surface を使うことがありますが、RFK は field helper / Tom Select wiring、RTP は table metadata / saved preference behavior を見るため、PR body では smoke の目的を分けて書きます。

## PR body evidence template

```text
## internal UI gem bump evidence

- gem:
- issue:
- from:
- to:
- upstream readiness checked at:
- open upstream gates:
  - <none / issue / PR / human gate>
- docs-portal host-app smoke:
  - automated:
  - manual:
  - skipped:
- rollback target:
- boundary:
  - upstream package verification / public API / visual reference guard は再実行していません
  - runtime UI redesign / business spec / auth / DB / external API は変更していません
```

## Stop conditions

次のいずれかに当たる場合は、bump PR を作らず対象 Issue に停止理由と再開条件を残します。

- target SHA を作業直前に再計測できない。
- Bundler で `Gemfile.lock` を再生成できない。
- representative smoke を実行または確認できない。
- open upstream PR / proposal を current support として扱う必要がある。
- `rails_table_preferences#789` などの human gate を docs-portal 側で判断する必要がある。
- 複数 gem の同時 bump、UI redesign、DB / auth / external API、business spec 判断が必要になる。

## Related docs

- [internal UI gem release train readiness matrix](./internal-ui-gem-release-train-readiness-matrix.md)
- [internal gem release train smoke notes](./internal-gem-release-train-smoke.md)
- [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md)
- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md)
