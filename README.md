# Rails Portal Full Sample

Rails + Docusaurus を前提にした「社外秘ドキュメント配布ポータル」の雛形です。

## 利用者向け概要

- 案件ごとの文書公開、版管理、閲覧制御、添付配布を行う Rails ポータルです。
- Markdown 文書は Docusaurus build を公開物として扱います。
- 社外ユーザーの閲覧は `ProjectMembership` と `DocumentPermission` に基づきます。

## 開発者向け入口

- repo 固有ルールは [AGENTS.md](./AGENTS.md) と [docs/README.md](./docs/README.md) を正本とします。
- 構造や責務分離は [docs/開発・保守ガイド.md](./docs/開発・保守ガイド.md) を参照してください。
- フロントエンドの操作方針と `tree_view` / `rails_table_preferences` / `rails_fields_kit` の役割分担は [doc/frontend_interaction_policy.md](./doc/frontend_interaction_policy.md) を参照してください。
- 関連 gem の使用箇所と upstream docs / issue の入口は [docs/関連gem連携調査runbook.md](./docs/関連gem連携調査runbook.md) を参照してください。
- 権限や公開モデルは [docs/アプリケーション仕様.md](./docs/アプリケーション仕様.md) と配下の [分割仕様](./docs/specs/基本モデルと権限.md)、検証方針は [docs/テスト方針.md](./docs/テスト方針.md) を参照してください。
- ローカル編集から seed / import / portal 更新までの最小確認手順は [docs/ローカル編集からポータル更新までの最小運用案.md](./docs/ローカル編集からポータル更新までの最小運用案.md) を参照してください。
- 標準 seed サンプルの種類と確認用途は [docs/標準seedサンプルと確認用途.md](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を参照してください。
- Office preview の接続前提と確認手順は [docs/Microsoft Graph接続とOffice preview.md](./docs/Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を参照してください。
- Docusaurus seed build / manual preview renderer / Kroki の runtime 前提と関連環境変数は [docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md) を参照してください。

## 外部サンプル文書
- seed は `db/data/*.csv` に加えて、`storage/document_files/external_samples/` 配下に置かれたサンプル文書も拾います。
- 配置規約は `storage/document_files/external_samples/<sample-set>/<site-dir>/...` です。
- `sample-set` と `site-dir` の名前は任意です。seed 時には `site-dir` ごとに 1 Project を作ります。
- Markdown は 1 ファイルまたは 1 ディレクトリを 1 Document として取り込み、`README.md` はその階層のトップページとして扱います。
- `site-dir` 直下の Markdown は `current` 版、`編集正本` や `提出済` などのスナップショット用ディレクトリ配下の Markdown は別 `DocumentVersion` として取り込みます。
- Markdown が含まれる場合、`db:seed` 中に Docusaurus build も実行し、同一 site build を共有する各 `DocumentVersion` の `storage/docs_sites/<version.id>/...` を生成します。
- `markdown_entry_path` は source path の推測値ではなく、build 後の実 HTML 出力パスから確定します。
- HTML 表示は Document 詳細から辿れても、実際の配信 URL は Project 単位の `/projects/:id/site/...` に寄せます。
- そのため、開発者が seed 用サンプルを追加する場合は、Markdown 群が Docusaurus build を通せる内容である必要があります。build 失敗時は `db:seed` を失敗させます。
- seed build と manual Markdown/MDX upload preview は別経路です。preview renderer の compose 構成や `DOCUSAURUS_RENDERER_*` / `KROKI_ENDPOINT` の役割は [docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md) を参照してください。
- PlantUML / D2 を含むMarkdownをseedする場合は、Krokiの設定が必要です。詳しくは「ローカルKrokiを使う場合」を参照してください。
- repo 標準の showcase サンプルは、`db:seed` の先頭で `storage/document_files/external_samples/seed-showcase/docs-portal-demo/` に再生成されます。Markdown / Mermaid / PDF / Excel / CSV / 複数版の確認観点は [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を参照してください。
- AI活用ユースケース・手順書のサンプルは `storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/` にあります。通常の `rails db:seed` で取り込まれ、マスタ駆動で手順書・判断フローを管理するための初期コンテンツとして使えます。
- 標準 showcase、`ai-usecases`、任意の `external_samples` の役割分担は [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) にまとめています。
- 例:
```text
storage/document_files/external_samples/
└── kyodo-butsuryu-service/
    └── 作成資料/
        ├── README.md
        ├── 受領資料Markdown/
        │   ├── README.md
        │   └── 概要仕様書20250228.md
        ├── 社内メモ/
        │   ├── README.md
        │   └── ドメイン設計メモ.md
        ├── 編集正本/
        │   └── README.md
        └── 提出済/
            └── README.md
```
- 既存のサンプル文書を持ち込む場合は、対象ディレクトリをこの配下へ `cp -r` してください。
- `bin/setup_external_sample_data_links` は `storage/document_files/external_samples/` のベースディレクトリを作るだけです。

## ローカルKrokiを使う場合

PlantUML / D2 を含むMarkdownをDocusaurus buildする場合、`KROKI_ENDPOINT` が必要です。

標準の `docker-compose.yml` にはKrokiを含めていません。必要な場合だけ、追加Composeファイルを `.env` の `COMPOSE_FILE` に足して起動してください。

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml
KROKI_ENDPOINT=http://kroki:8000
```

`docker-compose.kroki.yml` を有効化している場合、`docker compose run --rm app ...` 実行時も `kroki` が依存サービスとして起動対象になります。

ローカルPCからKrokiにアクセスしたい場合は、必要に応じて公開ポートを変更できます。

```env
PUBLISH_KROKI_PORT=8000
```

起動例:

```bash
docker compose up -d kroki
```

その後、通常どおり `rails db:seed` を実行します。

## 運用メモ
- `storage/imports/` は internal import API が読み取ってよい唯一の import ルートです。`artifact_root` と `manifest_path` はこの配下に置いてください。
- 社外ユーザーの Project 参照は `project_memberships` がある案件に限定されます。
- 社外ユーザーの添付ファイル配信は `DocumentPermission.access_level = download` がある場合だけ許可されます。
- 文書詳細の「表示」リンクは、対応する Docusaurus 生成 HTML が実在する版にだけ出ます。

## サンプルログイン情報
- admin@example.com / password123!
- staff@example.com / password123!
- client-a@example.com / password123!
- client-b@example.com / password123!