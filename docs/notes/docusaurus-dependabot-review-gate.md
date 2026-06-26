# Docusaurus Dependabot review gate

Docusaurus / npm 系 Dependabot PR で `Maintainer changes` や `Install script changes` が出た場合は、`docs-quality` / `ci` が success でも merge 判断を完了したとは扱いません。この note は manual review checklist と証跡の置き場所を固定するためのものです。PR #3056 / #3057 の package update、lockfile 更新、rebase / recreate をこの docs 変更に含めません。

## まず分けるもの

- `docs-quality` / `ci` success: Markdown lint、relative link check、Kroki mock smoke、Rails 側の代表 CI が通ったことだけを示します。
- PR metadata の `mergeable`: branch freshness や conflict が merge 可能かを示します。
- Dependabot metadata: maintainer change、install script change、package contents の review 要否を示します。
- human review: package metadata / install script / docs build impact を確認し、PR body または PR comment に証跡を残す判断です。

## 確認する範囲

`Maintainer changes` または `Install script changes` が Dependabot body にある場合は、次だけを確認します。

1. Dependabot body の metadata section を読み、maintainer が変わった package と install script が変わった package を特定する。
2. `docusaurus/package.json` と `docusaurus/package-lock.json` の差分で、対象 package と transitive dependency の更新範囲を確認する。
3. install script が追加・変更された場合は、対象 package の script 名と実行される内容を確認する。必要に応じて package contents の確認要否を PR comment に残す。
4. `docs-quality`、Docusaurus build、Kroki mock smoke、Mermaid / ELK など docs rendering への影響を分けて確認する。
5. 確認した内容を PR body または PR comment に `manual evidence` として短く残す。

## rebase 不能時の recreate / replacement 判断

`@dependabot rebase` に対して Dependabot が「Dependabot 以外の編集が入っているため rebase できない」「必要なら `@dependabot recreate`」という趣旨を返した場合は、CI failure や branch freshness とは別の判断として扱います。

1. PR metadata の `head_sha`、compare の `ahead_by` / `behind_by` / `status`、最新 head の workflow run を控える。
2. PR branch に Dependabot 以外の commit、maintainer による lockfile 手修正、PR body / comment で合意した manual evidence があるか確認する。
3. 既存編集を破棄してよいと maintainer が判断できる場合だけ、`@dependabot recreate` を候補にする。`recreate` は既存の人手編集を上書きしうるため、自動実行や流れ作業の refresh として扱わない。
4. 既存編集を残す必要がある場合は、replacement branch / 新 PR に必要差分を逃がすか、checkout 可能な環境で手動 lockfile refresh を行うかを maintainer 判断に戻す。
5. recreate 後や replacement 後は、過去 head の green CI を流用せず、current head の `docs-quality` / `ci`、必要なら `security-audit` / `build-docs` job、`mergeable`、compare freshness を取り直す。
6. Mermaid / ELK など rendering impact がある場合は、recreate 後も visual evidence / manual review gate を別項目として残す。

PR comment には次の粒度で十分です。

```markdown
rebase / recreate evidence:
- current head: <sha>
- freshness: ahead_by=<n> / behind_by=<n> / status=<ahead|diverged|behind>
- Dependabot rebase: 人手編集済みのため不可
- existing edits: <破棄してよい / 残す必要あり / 判断待ち>
- next action: <recreate候補 / replacement候補 / manual lockfile refresh候補 / needs-human>
- current blockers: <fresh CI / security-audit / build-docs / visual evidence / manual review gate>
```

`security-audit` failure、branch freshness、manual evidence blocker は混同しません。たとえば Docusaurus dependency の audit failure が主因なら dependency tree と audit step を先に分け、Mermaid / ELK の visual evidence が主因なら browser-capable evidence を別に残します。

## Current PR mixed evidence examples

open Docusaurus Dependabot PR を記録する場合は、個別 PR の採否をこの note で確定せず、次のように evidence family を分けて残します。

| PR | workflow evidence | freshness evidence | manual blocker | next action wording |
| --- | --- | --- | --- | --- |
| #3057 `@mermaid-js/layout-elk` | head `9390316732a8cb8d7fa87669d4e7ed25940420da` の `docs-quality #1612` / `ci #6607` は success | current `main` `5a71613f3393b85f49cb01d7647721333a09ccb7` に対して `ahead_by:1`, `behind_by:5`, `status:diverged`。changed files は `docusaurus/package.json` / `docusaurus/package-lock.json` | Mermaid / ELK rendering impact は CI success と別に browser-capable evidence または human visual review が必要 | latest main への refresh / fresh CI と、edge routing / label readability の代表 visual evidence 待ち。dependency bump 自体の採否はここで決めない |
| #3365 `dompurify` | head `3403f0b895dafd12ba449fb6149d629ec6f4ddc8` の `docs-quality #1657` / `ci #6719` は success。combined status は空だが workflow run は存在 | current `main` `f8b956362ab2c051794e24d47215c572499b32d7` に対して `ahead_by:5`, `behind_by:52`, `status:diverged`。effective changed file は `docusaurus/package-lock.json` | sanitizer dependency の supply-chain / security-adjacent review と、古い branch / fresh CI 待ちは別項目にする。過去の `ci #6274` failure / Ruby audit drift は historical blocker として current head の採否から分ける | latest main への refresh / fresh CI と human review 待ち。recreate / replacement / manual lockfile refresh、lockfile 手修正、merge 判断は人間判断として別 lane に戻す |

combined commit status が空でも workflow run がある場合は、`checks not found` ではなく「combined status は空、workflow run は存在」と書きます。`mergeable:true` は conflict がないことの目安であり、fresh CI、manual evidence、visual evidence、security-adjacent adoption decision の代替にはしません。

この例は `docs/notes/docusaurus-dependabot-review-gate.md` の記録粒度をそろえるためのものです。Dependabot PR の rebase / recreate、`package-lock.json` の再生成、Docusaurus dependency 採用判断、visual regression CI 導入はこの docs note では実行しません。

## 証跡の書き方

PR comment には次の粒度で十分です。

```markdown
manual evidence:
- Dependabot metadata: Maintainer changes / Install script changes を確認
- package diff: docusaurus/package.json と docusaurus/package-lock.json の対象 package を確認
- install script: <package name> の <script name> を確認。追加の package contents review は <必要 / 不要>
- docs impact: docs-quality / Docusaurus build / Kroki smoke / visual evidence の必要範囲を確認
- conclusion: CI success とは別に human review 済み / 追加確認待ち
```

`docs-quality` や `ci` が success していても、この証跡がない場合は `review:needs-human` として残します。

## Mermaid / ELK visual evidence gate との分離

Mermaid / ELK など rendering 結果に影響しうる update は、代表 fixture や目視 evidence の要否を別に確認します。この note は maintainer / install script / package metadata の review gate であり、visual evidence gate の内容を置き換えません。

## この note で決めないこと

- Dependabot auto-merge policy
- npm package allow / deny list
- 全社的 supply-chain policy
- `npm audit` / provenance / package contents verifier の CI 強制導入
- PR #3056 / #3057 の dependency bump、lockfile 更新、rebase / recreate
