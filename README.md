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
- Pundit policy 雛形
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
- 配置規約は `storage/document_files/external_samples/<sample-set>/<document-dir>/...` です。
- `sample-set` と `document-dir` の名前は任意です。`document-dir` ごとに 1 文書として取り込みます。
- 例:
```text
storage/document_files/external_samples/
└── kyodo-butsuryu-service/
    ├── edit-original/
    ├── edit-pdf/
    └── submitted/
```
- 既存の `/mnt/c/work/TKK/WMS/kyodo-butsuryu-service/作成資料` から持ち込む場合は、必要なディレクトリをこの配下へ `cp -r` してください。
- `bin/setup_external_sample_data_links` は `storage/document_files/external_samples/` のベースディレクトリを作るだけです。

## サンプルログイン情報
- admin@example.com / password123!
- staff@example.com / password123!
- client-a@example.com / password123!
- client-b@example.com / password123!
