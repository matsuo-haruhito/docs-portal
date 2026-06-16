# internal UI gem release train adoption gates

この文書は、internal UI gem の release train に入れる upstream public / package surface PR を選ぶ前の最小確認基準です。`docs/internal-ui-gem-release-train-current-queue.md` と `docs/関連gem連携調査runbook.md` を読む前に、どの PR を採用候補にしてよいかを同じ粒度で見るための短い gate として使います。

## 採用候補にする最低条件

upstream PR を release train の採用候補にする前に、次を同時に確認します。

- current main から `behind_by:0`、または差分が明示的に許容され、review comment や issue comment に理由が残っている
- head SHA に紐づく workflow run が success している。combined status が空でも workflow run を確認する
- changed files が package surface、declaration、manifest、docs、package verifier、sample evidence のどれに属するか説明できる
- open proposal や未 merge PR の export 名を `docs-portal` の current support として書かない
- Gemfile bump、downstream smoke、rollback note は、この gate を通った SHA だけで別 issue / PR に戻す

## repo ごとの主 evidence

| repo / gem | 主 evidence family | 採用候補として読む条件 | まだ広げないこと |
| --- | --- | --- | --- |
| `rails_table_preferences` | package verifier、README / docs index、`docs/javascript_entrypoints.md`、manual QA matrix | CSS subpath export や package entrypoint が current main 上で green で、package verifier / docs source-of-truth と矛盾しない | copied controller 方針、dirty-state UI、preview iframe table への適用判断 |
| `tree_view-rails` | public API manifest、TypeScript declaration、README / `docs/ja/*`、package contents guard | manifest / declaration / docs signal が同じ head SHA で揃い、sidebar tree / detail tree smoke の対象 export が current support として読める | open proposal の hook 名、selection contract、browser visual evidence の代替判断 |
| `rails_fields_kit` | package-root export smoke、`doc/public_api.md`、setup docs、sample / visual evidence | helper や controller export が public docs と runtime smoke の両方で確認でき、fresh CI 後に target SHA を絞れる | open helper family の先取り、visual behavior の最終判断、host app 固有 params の upstream 化 |
| `docs-portal` | representative downstream smoke、Gemfile / Gemfile.lock diff、rollback note | upstream gate を通った SHA だけを 1 gem ずつ bump 候補にし、host app smoke と rollback target を PR に残せる | 3 gem 同時 bump、upstream PR の code review 代替、public API 採否の最終判断 |

## 既存 issue との役割分担

- `#3229`: この文書のように、4 repo 横断の採用基準と evidence family を短く固定する
- `#3086`: stale / diverged upstream PR を current main へ refresh するか、後続 tranche へ回すかを整理する
- `#2555`: package-root / package-entrypoint public surface の採用順と repo ごとの evidence family を整理する
- `#2576`: `docs-portal#858` の first slice として target SHA と downstream smoke を決める
- `#858`: release train parent。実装や docs 更新の最小単位ではなく、child issue へ戻す hub として扱う

## release train へ戻すときの記録項目

採用候補を `docs-portal` 側の bump / smoke issue へ戻すときは、少なくとも次を 1 セットで残します。

```text
- upstream repo / PR:
- head SHA:
- compare against current main:
- workflow run:
- primary evidence family:
- downstream smoke candidate:
- rollback target:
- remaining human gate:
```

## 停止条件

次のどれかに当たる場合は、Gemfile bump や downstream smoke 実装へ進めず、対象 issue / PR に停止理由を残します。

- current main に追従しておらず、許容理由も残っていない
- workflow run が head SHA に対して success していない、または古い green evidence しかない
- public API、manifest、direct entrypoint、visual behavior の採否に人間判断が必要
- `docs-portal` で Gemfile / Gemfile.lock を更新できる検証環境がない
- 3 gem 同時 bump、UI redesign、DB / auth / external API、business spec 判断へ広がる

この gate は採用判断の入口であり、merge 判断そのものではありません。最終的な code review、public API 採否、Gemfile bump、representative smoke は、それぞれの repo / child issue / PR で分けて扱います。
