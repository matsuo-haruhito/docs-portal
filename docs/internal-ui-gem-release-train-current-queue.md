# internal UI gem release train current queue

この文書は、`docs/関連gem連携調査runbook.md` の release train 説明を読む前に確認する current queue snapshot です。

`docs-portal` の internal UI gem 更新は `#858` を parent / hub として扱います。実際の dependency bump は、ここにある current child issue と `docs/internal-gem-release-train-smoke.md` の代表 smoke / rollback note を合わせて確認します。

## current queue (2026-06-02 JST)

| 順序 | gem | current docs-portal ref | current child / gate | 扱い |
| --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `#1300` | 最初に見る release train child。checkout、Bundler lockfile regeneration、representative smoke ができる環境でだけ bump PR に進める |
| 2 | `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `#1301` | `#1300` の扱いを確認した後に進める child。sidebar tree / detail tree / persisted state smoke を分けて記録する |
| human-gated | `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `#789` | known-good target revision の人間判断待ち。human gate 前に broad bump や downstream canary を混ぜない |

## 関連 issue の読み分け

- `#858`: release train の parent / hub。実装や docs 更新の最小単位ではない。
- `#1509`: 完了済み。`docs/internal-ui-gem-public-surface-package-verification-matrix.md` を追加した matrix issue として参照する。
- `#1470`: state cue inventory の parallel design lane。dependency bump、target SHA、Gemfile / lockfile 更新とは混ぜない。
- `#1552`: この current queue を `docs/関連gem連携調査runbook.md` から誤読しないための docs sync issue。

## historical / old child numbers

`docs/関連gem連携調査runbook.md` に残る `#921`、`#903`、`#904` は historical context として読みます。current active lane として扱う場合は、必ず上の `#1300`、`#1301`、`#789` と `docs/internal-gem-release-train-smoke.md` を再確認します。

## bump 実行前の停止条件

- GitHub checkout / fetch ができず、target SHA を作業直前に再計測できない
- Bundler を実行できず、`Gemfile.lock` を正しく再生成できない
- representative smoke を実行または確認できず、PR 本文に結果を残せない
- 複数 gem の同時 bump、UI redesign、DB / auth / external API、business spec 判断が必要になる

この条件に当たる場合、Docs Sync Agent / Fixer は `Gemfile` や `Gemfile.lock` を connector で手編集せず、対象 issue に停止理由と再開条件を残します。

## 先に見る docs

- `docs/internal-gem-release-train-smoke.md`: human handoff、representative smoke、rollback target、update log template
- `docs/internal-ui-gem-public-surface-package-verification-matrix.md`: package-root export、direct entrypoint、manifest / package verification の境界
- `docs/関連gem連携調査runbook.md`: host app 採用パターン、screen-by-screen adoption、upstream docs 入口
