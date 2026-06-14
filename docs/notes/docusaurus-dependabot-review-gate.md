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
