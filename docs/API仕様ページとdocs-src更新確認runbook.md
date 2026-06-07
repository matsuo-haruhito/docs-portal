# API仕様ページと docs-src 更新確認 runbook

## この runbook の対象

`admin/api_specification` で確認できる Docusaurus HTML と、その source である `docs-src/*.md` の往復手順をまとめた runbook です。

次のようなときに使います。

- `docs-src/api-specification.md` や関連 Markdown を更新したあと、管理画面の HTML 表示まで確認したい
- internal import API、単体ファイルアップロード API、Office preview、外部フォルダ同期 Webhook の説明ページへ素早く入りたい
- API仕様ページの `表示状態` で build 待ち、source 更新、HTML未生成、直近 build 失敗を読み分けたい

この画面は admin-only です。`app/views/admin/_nav.html.slim` の `API仕様` から開きます。

## 正本と表示の関係

- source の正本は `docs-src/api-specification.md` と、同じ `docs-src/` 配下の関連 Markdown です
- 管理画面は、それらを Docusaurus build した HTML を iframe で表示します
- entry HTML は `docusaurus/build/api-specification/index.html` です
- source が HTML より新しい場合、画面表示時に build が enqueue されることがあります
- 直近 build 結果は API仕様ページ専用の status marker で表示されます。build queue 全体や Docusaurus build 履歴の一覧ではありません
- `表示状態` は API仕様ページ全体の build 結果です。`主要ページとsource` の各行は、個別ページごとの編集元と HTML 確認先を見分けるための cue として読みます
- 各行の `編集元Markdown` は直す Markdown file、`HTML確認先（build後）` は build 後に開く generated page です。Source を直しただけでは HTML が更新済みとは限らないため、build 成功後に HTML確認先まで開きます
- 各行の `Freshness` は、その行の source mtime と generated HTML mtime の比較だけを示します。build queue、iframe 配信可否、site route の安全境界、直近 build 履歴を代表するものではありません

現時点で API仕様ページの `主要ページとsource` から辿れる主な HTML と source は次の 4 つです。

- `API仕様・連携設定`: `docs-src/api-specification.md` -> `/api-specification`
- `単体ファイルアップロードAPI`: `docs-src/client-file-upload-api.md` -> `/client-file-upload-api`
- `Office preview`: `docs-src/office-preview.md` -> `/office-preview`
- `外部フォルダ同期 Webhook 受信仕様`: `docs-src/external-folder-sync-webhooks.md` -> `/external-folder-sync-webhooks`

`Admin::ApiSpecificationPage::PRIMARY_SOURCE_PAGES` と `docs-src/*.md` の front matter `slug` は request spec で対応を固定しています。source rename や slug 変更を行う場合は、`source_path`、front matter `slug`、`site_path`、主要ページの表示 label を同じ変更として確認します。

## 日常の確認手順

1. `docs-src/api-specification.md` または関連する `docs-src/*.md` を更新します。
2. 管理画面の `API仕様` を開きます。
3. 上部 notice と `表示状態` を見て、build が開始されたか、HTML が最新か、直近 build が失敗していないかを確認します。
4. `build 待ち/実行中` または `HTML未生成または stale` の場合は、少し待って再読み込みします。
5. `最新 build 成功` になったら、iframe で entry HTML を確認し、`主要ページとsource` の更新対象行で `編集元Markdown`、`HTML確認先（build後）`、`Freshness` を照合します。直した source file に対応する HTML確認先を開き、更新した説明が HTML 側にも反映されていることを確認します。
6. 行別 `Freshness` が `Source更新あり`、`HTML未生成`、`Source missing` の場合は、全体の `表示状態` が成功でも対象行だけを見直します。build 後に HTML確認先を開くか、source path / slug / site path の対応を確認します。
7. `build 失敗` の場合は、画面の短い失敗理由だけで断定せず、下の `build 失敗時の切り分け` へ進みます。

## 表示状態の見方

API仕様ページ上部の `表示状態` は、notice よりも現在の確認順を決める入口として見ます。

### `最新 build 成功`

- Docusaurus build 済み HTML が最新と見なせる状態です
- 必要に応じて再読み込みし、iframe と `主要ページとsource` の link 先を確認します
- `最終成功`、`最終記録`、`HTML更新時刻` が表示される場合は、docs-src の更新時刻と照合します

### `build 待ち/実行中`

- source の更新を検知し、Docusaurus build の開始要求が残っている状態です
- すぐに HTML が切り替わらないことがあります
- `build 開始要求` の時刻を確認し、少し待ってから再読み込みします

### `HTML未生成または stale`

- `docusaurus/build/api-specification/index.html` がまだ無いか、source が HTML より新しい状態です
- HTML がある場合でも古い内容の可能性があります
- build 開始後、完了してから再読み込みし、必要なら `HTML がまだ出ないとき` を確認します

### `build 失敗`

- 直近の API仕様 Docusaurus build が失敗した状態です
- 画面には短く sanitize された失敗理由だけが表示されます。token、絶対 path、長い stderr をそのまま正本にしません
- `最終記録` の時刻を見て、source、runtime、job / CI logs の順で切り分けます

## 行別 Freshness cue の見方

`主要ページとsource` の `Freshness` は、対象行ごとに source file と generated HTML の更新時刻を比べる read-only cue です。上部の `表示状態` が API仕様ページ全体の build 結果を示すのに対し、行別 `Freshness` は「どの source 行から確認を始めるか」を決める補助として使います。

### `HTML追従済み`

- source と generated HTML の更新時刻に大きな差がない状態です
- 最終確認では、対応する `HTML確認先（build後）` を開いて、実際の文言やリンクが意図どおりかを見ます

### `Source更新あり`

- source が generated HTML より新しい可能性があります
- build enqueue / build success の全体状態だけで完了扱いにせず、build 後にその行の HTML確認先を開き直します

### `HTML未生成`

- source はありますが、対応する generated HTML が見つからない状態です
- `site_path`、front matter `slug`、Docusaurus build 結果の対応を確認します

### `Source missing`

- `PRIMARY_SOURCE_PAGES` が指す source file が見つからない状態です
- source rename、削除、front matter `slug` 変更の途中でないかを確認し、HTML確認先だけを根拠に正しいと判断しません

## notice の見方

### `Docusaurus build を開始しました`

- source の更新を検知して build enqueue した状態です
- すぐに HTML が切り替わらないことがあります
- `表示状態` が `build 待ち/実行中` の間は少し待って再読み込みします

### `Markdown がHTMLより新しい状態です`

- source 更新に対して、まだ最新 build が見えていない状態です
- build 実行中か、build 完了前の可能性があります
- `表示状態` が `HTML未生成または stale` のまま続く場合は下の `HTML がまだ出ないとき` を確認します

### `Docusaurus build が必要です`

- `docusaurus/build/api-specification/index.html` がまだ無い状態です
- source Markdown 自体は `docs-src/` 側にある前提なので、runtime 前提や build 成否の確認へ進みます

## HTML がまだ出ないとき

1. `docs-src/api-specification.md` と関連ページの source file が存在するか確認します。
2. `主要ページとsource` の各行で、更新した source file と開くべき `HTML確認先（build後）` が対応しているか確認します。
3. `HTML確認先（build後）` は Docusaurus build 後の generated HTML を admin-only site route で開く入口です。raw source Markdown、`tmp/api_specification_build.*` marker、build root 外 file を読む入口として扱いません。
4. `docs-src/client-file-upload-api.md`、`docs-src/office-preview.md`、`docs-src/external-folder-sync-webhooks.md` の更新対象が想定どおりか確認します。
5. source rename や slug 変更をした場合は、`PRIMARY_SOURCE_PAGES` の `source_path` と `site_path`、Markdown front matter `slug` が同じ対応になっているか確認します。
6. Docusaurus runtime の前提が崩れていないか、[docs/notes/docusaurus-build-runtime.md](./notes/docusaurus-build-runtime.md) を確認します。
7. build 完了後も古い HTML のままなら、対象ページを再読み込みして `主要ページとsource` から入り直します。

API仕様ページは source を直接編集する画面ではありません。表示に違和感があるときは、まず `docs-src/` 側を正本として見直します。

## build 失敗時の切り分け

`ApiSpecificationBuildJob` は `Admin::ApiSpecificationPage#build!` を実行し、終了時に build request marker を消します。失敗時は API仕様ページ専用の status marker に短い失敗情報が残りますが、原因調査は画面表示だけで完結しないため、次の順で切り分けます。

1. `表示状態` が `build 失敗` か、`build 待ち/実行中` のままかを確認します。待ち状態なら、まだ失敗とは断定しません。
2. source file の有無を確認します。entry は `docs-src/api-specification.md` で、関連ページは `docs-src/client-file-upload-api.md`、`docs-src/office-preview.md`、`docs-src/external-folder-sync-webhooks.md` です。
3. 各 Markdown の front matter と slug を確認します。主要ページのリンク先は `/api-specification`、`/client-file-upload-api`、`/office-preview`、`/external-folder-sync-webhooks` です。
4. Docusaurus runtime 前提を確認します。`npm` や repo-local dependency の準備手順は [docs/notes/docusaurus-build-runtime.md](./notes/docusaurus-build-runtime.md) を正本にし、この runbook には重複して書きません。
5. job / CI logs を確認します。build command は `DOCUSAURUS_DOCS_PATH=docs-src` を渡して `docusaurus/` 配下で `npm run build` を実行します。stderr / stdout に source path、slug、link、package dependency のどれが出ているかを先に見ます。
6. GitHub Actions 側で落ちている場合は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) へ進み、`test` / `seed-smoke` / `build-docs` のどの段階の失敗かを分けます。

API仕様ページの `build 失敗` 表示は、管理者が次に確認する場所を決めるための短い signal です。source、runtime、job / CI logs の順で根拠を揃えてから、docs-src の修正か runtime / workflow 側の対応かを判断します。

## 更新対象の切り分け

- internal import API や Git / ZIP / file upload の説明を直すときは `docs-src/api-specification.md`
- 単体ファイルアップロードの説明を直すときは `docs-src/client-file-upload-api.md`
- Office preview / Microsoft Graph まわりを直すときは `docs-src/office-preview.md`
- 外部フォルダ同期 Webhook の説明を直すときは `docs-src/external-folder-sync-webhooks.md`

source 更新後は、API仕様ページの `主要ページとsource` で HTML まで見直してから完了にします。

## 関連ドキュメント

- [README.md](../README.md)
- [docs/README.md](./README.md)
- [docs/notes/docusaurus-build-runtime.md](./notes/docusaurus-build-runtime.md)
- [docs-src/api-specification.md](../docs-src/api-specification.md)
