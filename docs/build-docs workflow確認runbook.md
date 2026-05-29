# build-docs workflow確認runbook

この runbook は、issue `#686` と issue `#1039` に対応する maintainer 向けの確認メモです。

current `main` の `.github/workflows/build-docs.yml` を正本として、`test` `seed-smoke` `build-docs` の見分け方、`publish/manifest/publish.json` の生成、`docs-site.tar.gz` artifact、Rails import API 呼び出し条件、import failure 時の replay / rebuild 判断を追いやすくします。

新しい workflow や import 方式はここでは定義しません。既存実装で、どこを見てどこへ戻るかだけを整理します。

## 先に見る文書

1. `build-docs` job が作る manifest の形式は [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md)
2. 文書 repo 全体の最小運用は [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
3. Docusaurus / Kroki / manual preview renderer の runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
4. app 側の import 受け口や `storage/imports/` の前提は [README](../README.md) の `運用メモ` を見る

## 1. この workflow が走る条件

current workflow 名は `ci` で、docs build 専用 workflow が別にあるわけではありません。

- `test`: `push` (`dev`, `main`) と `pull_request` で走る
- `seed-smoke`: `push` (`dev`, `main`) と `pull_request` で走る
- `build-docs`: `test` 成功後に走るが、対象は `main` への push と `dependabot[bot]` の pull request だけ

つまり current 実装では、通常の human PR では `build-docs` job は走りません。PR で docs build 自体を確認したいときは、この前提を踏まえて `test` / `seed-smoke` と source diff を見ます。

## 2. 最初の切り分け順

1. GitHub Actions の run で、止まっている job が `test` `seed-smoke` `build-docs` のどれかを確認する
2. `test` で止まっていれば、Rails app 本体や spec failure を先に見る
3. `seed-smoke` で止まっていれば、`.env.example`、DB 準備、seed 前提、runtime note を見る
4. `build-docs` で止まっていれば、Docusaurus build、manifest 生成、artifact upload、import API 呼び出しのどこで止まったかを切り分ける
5. `build-docs` 自体が run に出ていない場合は、event が `main` push ではないか、Dependabot PR ではない可能性を先に疑う

## 3. `build-docs` job の中で何が起きるか

current `main` の `.github/workflows/build-docs.yml` では、`build-docs` job は次の順で進みます。

1. `actions/checkout@v6`
2. Node 24 を設定し、`docusaurus/package-lock.json` をキーに npm cache を使う
3. `docusaurus/` で `npm ci`
4. `docusaurus/` で `npm run build`
5. `node ./scripts/generate_publish_manifest.mjs --config ./publish/documents.json --output ./publish/manifest/publish.json ...` を実行する
6. `docusaurus/build` `attachments` `publish/manifest` をまとめて `docs-site.tar.gz` に固める
7. `docs-site` という名前で artifact を upload する
8. `main` push かつ import URL / token が両方ある場合だけ Rails import API を呼ぶ

`publish.json` は手編集ではなく、この job の中で `publish/documents.json` から生成されます。

## 4. `publish/manifest/publish.json` を確認したいとき

manifest 生成で見ている正本は次です。

- 入力: `publish/documents.json`
- 生成 script: `scripts/generate_publish_manifest.mjs`
- 出力: `publish/manifest/publish.json`

current script の要点:

- `publish` が truthy か、`status == "published"` の document だけを出力対象にする
- `files[*].source_path` が無ければ `attachments/<storage_key>` を実体として見る
- `file_size` 未指定時は実ファイルから自動計算する
- `site_build_path` がある document は `docusaurus/build/<site_build_path>/index.html` まで存在確認する
- `source_repo` `source_branch` `source_commit_hash` を workflow 実行時の repository / branch / sha で埋める
- `artifact.name` `artifact.workflow_run_id` `artifact.workflow_run_attempt` `artifact.manifest_path` を replay 判断用 metadata として埋める

manifest 生成 step で止まったときは、まず [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md) と `publish/documents.json`、必要なら `scripts/generate_publish_manifest.mjs` を見比べます。

## 5. `docs-site.tar.gz` artifact の役割

archive step では、次の 3 系統を 1 つの tarball にまとめます。

- `docusaurus/build`
- `attachments`
- `publish/manifest`

artifact 名は `docs-site` です。

この archive は「build 済み HTML」「配布ファイル」「今回の manifest」を同じ実行単位で束ねたものです。import API はこの workspace を前提に `artifact_root` と `manifest_path` を渡されます。

`publish/manifest/publish.json` の `artifact` metadata を見ると、少なくとも次を確認できます。

- artifact 名: `artifact.name`
- source repository: `artifact.source_repo`
- source branch: `artifact.source_branch`
- source commit: `artifact.source_commit_hash`
- workflow run: `artifact.workflow_run_id`
- workflow attempt: `artifact.workflow_run_attempt`
- manifest path: `artifact.manifest_path`

artifact 生成や upload で止まったときは、Docusaurus build の成否だけでなく、`attachments/` や `publish/manifest/` まで揃っているかを見直します。

## 6. Rails import API が呼ばれる条件

current workflow の `Call Rails import API` step は、次をすべて満たしたときだけ走ります。

- event が `push`
- ref が `refs/heads/main`
- `RAILS_PORTAL_IMPORT_URL` が空でない
- `RAILS_PORTAL_IMPORT_TOKEN` が空でない

そのため、次のケースでは artifact までは作られても import API は呼ばれません。

- `dev` への push
- 通常の pull request
- secret が未設定の環境

step 自体は `curl -X POST` で `artifact_root=$(pwd)` と `manifest_path=$(pwd)/publish/manifest/publish.json` を送ります。

import 側の前提を見直したいときは、[ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md) と [README](../README.md) の `運用メモ` を確認します。

## 7. failure 時の戻り先

### `test` で止まった

- Rails app や spec failure が先です
- docs build 起点ではなく、失敗した spec / app diff を確認します

### `seed-smoke` で止まった

- `bundle exec rails db:prepare` まで含めた seed 前提の崩れを疑います
- `.env.example` や runtime service 前提は [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md) と [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) に戻ります

### `Build Docusaurus site` で止まった

- `docusaurus/` 側の依存や build 前提を確認します
- Kroki や manual preview renderer まわりの runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) が入口です

### `Create manifest` で止まった

- `publish/documents.json` の対象、`attachments/` の実ファイル、`docusaurus/build/<site_build_path>/index.html` の存在を確認します
- manifest 仕様は [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md) を正本にします

### `Archive build output` または artifact upload で止まった

- `docusaurus/build` `attachments` `publish/manifest` の 3 つが揃っているかを見ます
- どれか 1 つでも欠けると archive 全体が成立しません

### `Call Rails import API` で止まった

- まず step が「呼ばれる条件を満たしていたか」を確認します
- 条件を満たしていて失敗したなら、import URL / token、app 側の import 受け口、`storage/imports/` 前提を見直します
- `docs-site` artifact を開ける場合は `publish/manifest/publish.json` の `artifact` metadata を見て、失敗した import がどの source commit / workflow run / manifest path 由来かを確認します
- app 側の運用入口は [README](../README.md) の `運用メモ` と [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md) です

## 8. import API failure 時の replay / rebuild 判断

`Call Rails import API` で失敗したときは、すぐ自動 replay せず、次の順で判断します。

1. `docs-site` artifact から `publish/manifest/publish.json` を確認する
2. `artifact.source_repo` `artifact.source_branch` `artifact.source_commit_hash` `artifact.workflow_run_id` `artifact.workflow_run_attempt` `artifact.manifest_path` を控える
3. 失敗原因が import URL / token / 一時的な network / Rails app 側の一時停止など、artifact の中身と無関係か確認する
4. artifact の中身と無関係な失敗で、同じ `source_commit_hash` の publish を再処理したいだけなら、同じ manifest / artifact を replay 候補にする
5. `publish/documents.json`、`attachments/`、Docusaurus source、manifest 生成 script、import schema のどれかが変わっている場合は replay ではなく rebuild を優先する
6. `slug + version_label` の重複や `latest_version` 影響があり得る場合は、replay 前に app 側の `PublishJob` と import 結果を確認する

同じ artifact / manifest を replay 候補にしてよい目安:

- `artifact.source_commit_hash` が再取り込みしたい commit と一致している
- `artifact.manifest_path` が `publish/manifest/publish.json` のまま
- artifact 内に `docusaurus/build` `attachments` `publish/manifest` が揃っている
- 失敗原因が artifact 内容の欠落や manifest validation ではない

rebuild を優先する目安:

- source commit が進んでいる、または replay したい commit が曖昧
- `publish/documents.json` や添付ファイルを修正済み
- Docusaurus build output を作り直す必要がある
- manifest schema や import API 側の解釈が変わっている
- artifact の保存期間が切れている、またはアクセス権で取得できない

## 9. 保存期間・アクセス制御の未決事項

この runbook は replay 判断のための metadata と手順だけを定義します。次はこの issue では決めません。

- `docs-site` artifact を GitHub Actions artifact 以外へ長期保存するか
- artifact の retention 日数
- 添付ファイルを含む artifact の閲覧権限、共有範囲、削除ポリシー
- Rails 側 `storage/imports/` に workflow run 単位で保持するか
- replay を UI / task / workflow_dispatch のどこから実行するか

artifact には添付ファイルが含まれるため、保存期間やアクセス制御は別 issue で人間判断を入れて扱います。

## 10. 日常確認ポイント

- `build-docs` job が走る event かどうか
- `publish/documents.json` を直接正本として編集し、`publish/manifest/publish.json` は生成物として扱えているか
- `docs-site` artifact に HTML / attachments / manifest が同梱される前提を崩していないか
- import API が走らなかったときに「failure」ではなく「条件未達」を切り分けられているか
- import API failure 時に `artifact` metadata から source commit / workflow run / manifest path を追えるか
- replay する前に、同じ artifact を使うべき失敗か、rebuild すべき失敗かを分けられているか

## 関連ファイル

- `.github/workflows/build-docs.yml`
- `scripts/generate_publish_manifest.mjs`
- `publish/documents.json`
- `docs/publish.json 仕様と生成ルール.md`
- `docs/ローカル編集からポータル更新までの最小運用案.md`
- `docs/notes/docusaurus-build-runtime.md`
- `README.md`
