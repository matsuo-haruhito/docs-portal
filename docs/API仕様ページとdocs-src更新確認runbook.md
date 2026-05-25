# API仕様ページと docs-src 更新確認 runbook

## この runbook の対象

`admin/api_specification` で確認できる Docusaurus HTML と、その source である `docs-src/*.md` の往復手順をまとめた runbook です。

次のようなときに使います。

- `docs-src/api-specification.md` や関連 Markdown を更新したあと、管理画面の HTML 表示まで確認したい
- internal import API、単体ファイルアップロード API、Office preview、外部フォルダ同期 Webhook の説明ページへ素早く入りたい
- API仕様ページで `build` 待ちや stale notice が出たとき、何を見直せばよいか確認したい

この画面は admin-only です。`app/views/admin/_nav.html.slim` の `API仕様` から開きます。

## 正本と表示の関係

- source の正本は `docs-src/api-specification.md` と、同じ `docs-src/` 配下の関連 Markdown です
- 管理画面は、それらを Docusaurus build した HTML を iframe で表示します
- entry HTML は `docusaurus/build/api-specification/index.html` です
- source が HTML より新しい場合、画面表示時に build が enqueue されることがあります

現時点で API仕様ページから辿れる主な HTML は次の 4 つです。

- `API仕様・連携設定`
- `単体ファイルアップロードAPI`
- `Office preview`
- `外部フォルダ同期 Webhook 受信仕様`

## 日常の確認手順

1. `docs-src/api-specification.md` または関連する `docs-src/*.md` を更新します。
2. 管理画面の `API仕様` を開きます。
3. 上部 notice を見て、build が開始されたか、まだ stale のままかを確認します。
4. notice が消えたら再読み込みし、iframe で最新 HTML が表示されることを確認します。
5. `主要ページ` のリンクを順に開き、更新した説明が HTML 側にも反映されていることを確認します。

## notice の見方

### `Docusaurus build を開始しました`

- source の更新を検知して build enqueue した状態です
- すぐに HTML が切り替わらないことがあります
- 少し待って再読み込みし、notice が消えてから内容を確認します

### `Markdown がHTMLより新しい状態です`

- source 更新に対して、まだ最新 build が見えていない状態です
- build 実行中か、まだ build 完了前の可能性があります
- まず再読み込みし、それでも続く場合は下の `HTML がまだ出ないとき` を確認します

### `Docusaurus build が必要です`

- `docusaurus/build/api-specification/index.html` がまだ無い状態です
- source Markdown 自体は `docs-src/` 側にある前提なので、runtime 前提や build 成否の確認へ進みます

## HTML がまだ出ないとき

1. `docs-src/api-specification.md` と関連ページの source file が存在するか確認します。
2. `docs-src/client-file-upload-api.md`、`docs-src/office-preview.md`、`docs-src/external-folder-sync-webhooks.md` の更新対象が想定どおりか確認します。
3. Docusaurus runtime の前提が崩れていないか、[docs/notes/docusaurus-build-runtime.md](./notes/docusaurus-build-runtime.md) を確認します。
4. build 完了後も古い HTML のままなら、対象ページを再読み込みして主要ページリンクから入り直します。

API仕様ページは source を直接編集する画面ではありません。表示に違和感があるときは、まず `docs-src/` 側を正本として見直します。

## 更新対象の切り分け

- internal import API や Git / ZIP / file upload の説明を直すときは `docs-src/api-specification.md`
- 単体ファイルアップロードの説明を直すときは `docs-src/client-file-upload-api.md`
- Office preview / Microsoft Graph まわりを直すときは `docs-src/office-preview.md`
- 外部フォルダ同期 Webhook の説明を直すときは `docs-src/external-folder-sync-webhooks.md`

source 更新後は、API仕様ページの `主要ページ` で HTML まで見直してから完了にします。

## 関連ドキュメント

- [README.md](../README.md)
- [docs/README.md](./README.md)
- [docs/notes/docusaurus-build-runtime.md](./notes/docusaurus-build-runtime.md)
- [docs-src/api-specification.md](../docs-src/api-specification.md)
