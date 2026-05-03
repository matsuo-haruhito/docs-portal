# Rails Portal Full Sample

Rails + Docusaurus を前提にした「社外秘ドキュメント配布ポータル」の雛形です。

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
- PlantUML / D2 を含むMarkdownをseedする場合は、Krokiの設定が必要です。詳しくは「ローカルKrokiを使う場合」を参照してください。
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
- 既存の `/mnt/c/work/TKK/WMS/kyodo-butsuryu-service/作成資料` から持ち込む場合は、必要なディレクトリをこの配下へ `cp -r` してください。
- `bin/setup_external_sample_data_links` は `storage/document_files/external_samples/` のベースディレクトリを作るだけです。

## ローカルKrokiを使う場合

PlantUML / D2 を含むMarkdownをDocusaurus buildする場合、`KROKI_ENDPOINT` が必要です。

標準の `docker-compose.yml` にはKrokiを含めていません。必要な場合だけ、追加Composeファイルを `.env` の `COMPOSE_FILE` に足して起動してください。

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml
KROKI_ENDPOINT=http://kroki:8000
```

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
