# Rails Portal Full Sample

Rails + Docusaurus を前提にした「社外秘ドキュメント配布ポータル」の雛形です。

## 関連メモ
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [publish.json 仕様と生成ルール](./publish.json仕様と生成ルール.md)

この ZIP は **既存 Rails プロジェクトへ載せやすい骨組み** を意図しています。
`rails new` 直後の全ファイルは含めず、以下を中心に入れています。

- CSV seed (`db/seeds.rb` + `db/data/*.csv`)
- `storage/document_files/external_samples/` 配下のサンプル文書参照
- モデル雛形
- 権限制御の model / controller 雛形
- controller / view の最小画面
- migration 雛形
- Dockerfile / docker-compose
- import service 雛形
- GitHub Actions 雛形
- Docusaurus 設定サンプル
- storage のサンプル HTML / 添付ファイル

## 想定手順
1. Rails プロジェクトを作成
2. この ZIP の内容を上書き配置
3. `bundle add pundit`
4. 認証基盤を入れる
5. `docker compose up --build`
6. `docker compose exec app bin/rails db:prepare`
7. 必要なら `bin/setup_external_sample_data_links`
8. `docker compose exec app bin/rails db:seed`

## 外部サンプル文書
- seed は `db/data/*.csv` に加えて、`storage/document_files/external_samples/` 配下に置かれたサンプル文書も拾います。
- 配置規約は `storage/document_files/external_samples/<sample-set>/<site-dir>/...` です。
- `sample-set` と `site-dir` の名前は任意です。seed 時には `site-dir` ごとに 1 Project を作ります。
- Markdown は 1 ファイルまたは 1 ディレクトリを 1 Document として取り込み、`README.md` はその階層のトップページとして扱います。
- `site-dir` 直下の Markdown は `current` 版、`編集正本` や `提出済` などのスナップショット用ディレクトリ配下の Markdown は別 `DocumentVersion` として取り込みます。
- Markdown が含まれる場合、`db:seed` 中に Docusaurus build も実行し、同一 site build を共有する各 `DocumentVersion` の `storage/docs_sites/<version.id>/...` を生成します。
- HTML 表示は Document 詳細から辿れても、実際の配信 URL は Project 単位の `/projects/:id/site/...` に寄せます。
- そのため、開発者が seed 用サンプルを追加する場合は、Markdown 群が Docusaurus build を通せる内容である必要があります。build 失敗時は `db:seed` を失敗させます。
- 例:
```text
storage/document_files/external_samples/
└── kyodo-butsuryu-service/
    └── 作成資料/
        ├── README.md
        ├── 受領資料Markdown/
        │   ├── README.md
        │   └── 共同物流サービス様WCS概要仕様書20250228.md
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
