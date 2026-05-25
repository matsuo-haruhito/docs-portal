# 管理ダッシュボード・モデルブラウザ運用runbook

この runbook は、管理画面の `ダッシュボード` と `モデルブラウザ` を日常運用で見返すときの入口をまとめる。

新しい診断ルールや監視基準はここでは定義しない。current 実装を前提に、`モデル観測` `アプリ設定診断` `文書ファイル健全性` をどう使い分け、必要に応じてどこへ戻るかを整理する。

## 先に見るもの

1. 環境変数や compose の前提を確認したいときは [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
2. Docusaurus build や Kroki の runtime 前提を確認したいときは [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
3. `storage/document_files` や欠落ファイル時の扱いを確認したいときは [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
4. 管理画面の位置関係は `app/views/admin/_nav.html.slim` の `ダッシュボード` と `モデルブラウザ` を起点に確認する

## 画面の役割

`admin/dashboard` は internal admin だけが使える運用確認の入口で、`モデル観測` `アプリ設定診断` `文書ファイル健全性` を 1 画面で見比べる。

current 実装の前提:

- `モデル観測` は `Admin::ModelBrowserCatalog.entries.first(8)` を並べ、主要な model だけを最初に見せる
- `アプリ設定診断` は `ApplicationConfigurationDiagnostic` の check を `OK / 警告 / エラー` 件数つきで出す
- `文書ファイル健全性` は `DocumentFileHealthCheck` で総件数と実体欠落件数を出し、欠落ファイルは最大 20 件まで一覧表示する
- 画面下部の `基本マスタ` `関連設定` は、日常確認後に既存の管理画面へ戻る近道として置かれている

## 1. モデル観測とモデルブラウザ

### ダッシュボード側で見ること

- `モデル観測` カードは、会社・ユーザー・案件・案件所属・文書などの主要 model について、件数と最終更新をざっと確認するために使う
- ここで「件数が急に増減していないか」「直近でどの領域が更新されたか」を把握してから、必要なら詳細へ進む
- dashboard から見えるのは catalog の先頭 8 件だけなので、周辺 model まで横断したいときは `モデルブラウザを開く` へ進む

### モデルブラウザ側で見ること

`admin/model_browser` は catalog に載っている model を一覧し、各 model の件数・最終更新・最近の record を read-only に確認する画面。

current 実装の前提:

- index では各 model の `件数` と `最終更新` を並べる
- show では model ごとに最近 20 件の record を、catalog が持つ `summary_fields` で表示する
- `既存画面へ` がある model は、そのまま管理画面の一覧へ戻れる
- `DocumentVersion` `DocumentFile` など既存の専用 index がないものも、ここでは最新 record の代表値を見返せる

使い分け:

- まず変化の有無をざっと見たい: `ダッシュボード`
- model 全体の件数や最終更新を横断で比較したい: `モデルブラウザ` index
- 最近の record の shape や値を短く確認したい: `モデルブラウザ` show
- 編集や登録をしたい: `モデルブラウザ` ではなく `既存画面へ` から元の管理画面へ戻る

## 2. アプリ設定診断

`アプリ設定診断` は、起動に必要な前提や sample 値の流用を current app がどう見ているかを一覧で返す。

current 実装の前提:

- 必須環境変数では `DATABASE_*` `ACTIVE_STORAGE_SERVICE` `PUBLISH_WEB_SERVER_PORT` と Active Record encryption key 群を確認する
- 数値項目では `DATABASE_PORT` `PUBLISH_WEB_SERVER_PORT` `RAILS_MAX_THREADS` が整数として解釈できるかを確認する
- secret 系では `SECRET_KEY_BASE` `RAILS_MASTER_KEY` `DOC_IMPORT_TOKEN` を確認し、sample 値のままなら warning または error にする
- storage / workspace 系では `config/storage.yml` に `ACTIVE_STORAGE_SERVICE` が存在するか、`storage/document_files` に書き込めるか、`docusaurus/package.json` があるか、`KROKI_ENDPOINT` が前提と合っているかを確認する
- `補足` 列には問題になっている値や path が出ることがある

見方:

- `OK` は current 前提を満たしている
- `警告` は今すぐ致命傷ではないが、sample 値の流用や optional service 前提の不足がある
- `エラー` は起動や build、import、preview に直結する不足で、先に解消したい項目

戻り先:

- `.env.example` 基準の設定値や compose 切り替えを見直したいときは [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
- Docusaurus workspace や Kroki 前提を見直したいときは [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
- `ACTIVE_STORAGE_SERVICE` や `storage/document_files` の扱いを見直したいときは [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)

## 3. 文書ファイル健全性

`文書ファイル健全性` は、登録済み `DocumentFile` に対応する実体ファイルが app から見えているかを確認する。

current 実装の前提:

- `登録ファイル数` は `DocumentFile` 総数
- `実体欠落` は `DocumentFile#absolute_path` に実ファイルが存在しなかった件数
- 欠落一覧は最大 20 件までで、`案件` `文書` `版` `ファイル名` `Storage key` を表示する
- 一覧の `文書` は公開側の project/document detail、`版` は document version detail へ戻れる

読み方:

- `実体欠落` が 0 でないときは、まず欠落が特定案件だけか、複数案件へ広がっているかを見る
- `Storage key` は storage 配下の期待位置を見直す手がかりとして使う
- `文書` や `版` へ戻り、対象が current 版か添付・原本か、import 直後の版かを確認する

注意点:

- この check は app が参照する filesystem 上で `File.file?` を見る current 実装であり、外部ストレージ API の疎通確認まではしない
- 欠落ファイルの詳細は最大 20 件までなので、全件洗い出し画面ではない
- 権限不足や公開条件の問題を診断する画面ではなく、まず「物理ファイルが見えるか」を切り分けるための入口として使う

## 日常確認ポイント

- model 数や最終更新に急な変化がないか
- `警告` `エラー` が、sample 値の流用なのか実運用に影響する不足なのか
- 欠落ファイルが単発なのか、storage 全体の問題に見えるのか
- dashboard だけで完結させず、必要な既存管理画面や仕様 docs にすぐ戻れているか

## 迷ったときの切り分け

- まず全体の変化や異常の有無を見たい: `ダッシュボード`
- 特定 model の件数や最近の record を見たい: `モデルブラウザ`
- `.env` や compose の設定不足を見たい: `アプリ設定診断`
- 実体ファイルが見えない原因を切り分けたい: `文書ファイル健全性`
- 個別のアクセス履歴や利用傾向を追いたい: [監査ログ運用runbook](./監査ログ運用runbook.md) や [文書利用状況運用runbook](./文書利用状況運用runbook.md) に戻る

## 関連画面

- `app/controllers/admin/dashboard_controller.rb`
- `app/views/admin/dashboard/index.html.slim`
- `app/controllers/admin/model_browsers_controller.rb`
- `app/views/admin/model_browsers/index.html.slim`
- `app/views/admin/model_browsers/show.html.slim`
- `app/services/admin/model_browser_catalog.rb`
- `app/checks/application_configuration_diagnostic.rb`
- `app/checks/document_file_health_check.rb`
