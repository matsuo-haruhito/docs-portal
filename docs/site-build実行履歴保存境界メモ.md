# site build 実行履歴保存境界メモ

このメモは issue `#3631` / `#3636` の first slice として、生成ファイル実行履歴を search index / site build / import build へ広げる前に、代表対象と保存境界を 1 つに絞って確認するための境界メモです。

代表対象は `Docusaurus site build / docs-site artifact` だけです。current 実装では `GeneratedFiles::SiteBuildArtifactRunRecorder` が allowlist 済み metadata を `GeneratedFileRun` として保存します。search index rebuild、import build handoff、retry / replay / alert / scheduled job はここでは実装・仕様化しません。

## 正本として見る current workflow

current repo では `.github/workflows/build-docs.yml` の `build-docs` job が、Docusaurus build、manifest 生成、artifact archive、必要条件を満たす場合の Rails import API 呼び出しを担当します。

運用時の確認順は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) を正本にします。このメモは、その runbook に出てくる `docs-site` artifact と `publish/manifest/publish.json` の metadata のうち、`GeneratedFileRun` に残す current 境界だけに絞ります。

## 代表対象

- 対象: Docusaurus site build
- artifact 名: `docs-site`
- manifest path: `publish/manifest/publish.json`
- artifact 内容: `docusaurus/build`、`attachments`、`publish/manifest`
- 確認目的: どの workflow run / commit / manifest 由来の site build だったかを後から追えるようにする

current 実装では、`docs-site` artifact の read-only evidence を `GeneratedFileRun` に保存します。これは app 内の通常生成ジョブと同じ一覧 / 詳細で検索・確認できるようにするための最小履歴であり、artifact 本体の保存や再実行導線ではありません。

## current GeneratedFileRun への載せ方

`GeneratedFiles::SiteBuildArtifactRunRecorder` は、site build artifact の代表 metadata を次の固定値とともに保存します。

- `job_id`: `docusaurus_site_build_artifact`
- `generator`: `docusaurus_site_build`
- `output_writer`: `docs_site_artifact`
- `event_source`: `docusaurus_site_build`
- `source_paths`: `publish/manifest/publish.json`
- `generated_paths`: `docs-site.tar.gz` と manifest path
- `metadata.read_only_evidence`: `true`

`status` は generated file run lifecycle に対応する値だけを受け付けます。`success` / `completed` は `completed`、`failure` / `failed` は `failed`、`cancelled` / `skipped` は `skipped`、`in_progress` / `running` は `running` として扱います。unsupported status は保存せず error にします。

## 保存してよい metadata

保存対象は、current workflow と manifest から追える最小 metadata に限定します。

- `status`: workflow / artifact processing の状態
- `started_at` / `finished_at`: GitHub Actions run 由来の時刻
- `artifact.name`: `docs-site`
- `artifact.source_repo`: build 元 repository
- `artifact.source_branch`: build 元 branch
- `artifact.source_commit_hash`: build 元 commit
- `artifact.workflow_run_id`: GitHub Actions run id
- `artifact.workflow_run_attempt`: GitHub Actions run attempt
- `artifact.manifest_path`: `publish/manifest/publish.json`
- `manifest_document_count`: manifest 上の公開対象件数を数える場合の集計値

`started_at` / `finished_at` を保存する場合は、アプリ側で推測せず、workflow run や artifact processing の観測時刻を明示します。

## 保存しない raw payload

次の値は、履歴として長期保存しません。必要なときは artifact / workflow run の権限内で都度確認します。

- absolute raw path / local private path
- import token / secret-like env
- external service token
- `docs-site.tar.gz` 全文
- `publish/manifest/publish.json` 全文の長期保存
- 巨大 artifact manifest / build log 全文
- `attachments/` 配下のファイル本文
- Rails import API request payload 全文
- CI log 全文

artifact には添付ファイルが含まれるため、artifact 本体の retention、長期保存、外部 storage 連携、閲覧権限は別 issue で人間判断を入れて扱います。

## 履歴化するときの読み分け

`docs-site` artifact の履歴では、少なくとも次を読み分けます。

- build は成功したが import API は条件未達で呼ばれていない
- build / manifest / archive / artifact upload のどこで失敗したか
- import API failure が artifact 内容由来か、一時的な URL / token / app 側状態由来か
- replay 候補なのか rebuild 優先なのか
- GitHub Actions artifact retention 内で確認できる情報なのか、アプリ側に保存した metadata なのか

current first slice は read-only evidence 保存です。replay、rebuild、alert、scheduled job、artifact download UI は追加しません。

## follow-up 候補

今回の代表対象に含めないものは、必要になった時点で別 issue に分けます。

- search index rebuild の履歴
- import build handoff の履歴
- replay / rebuild の実行導線
- alert / notification / scheduled job
- artifact retention policy の最終決定
- long-term artifact storage
- artifact 本体 download / preview

## 確認観点

- `docs-site` artifact 以外の代表対象を同時に増やさない
- secret-like value や private path を保存・表示対象として扱わない
- artifact 本体、manifest 全文、CI log、import API request payload を `GeneratedFileRun.metadata` に保存しない
- current workflow の metadata 名は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) と [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md) に戻って確認する
