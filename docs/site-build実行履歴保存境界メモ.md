# site build 実行履歴保存境界メモ

このメモは issue `#3631` の first slice として、生成ファイル実行履歴を search index / site build / import build へ広げる前に、代表対象と保存境界を 1 つに絞って確認するための proposal です。

代表対象は `Docusaurus site build / docs-site artifact` だけにします。search index rebuild、import build handoff、retry / replay / alert / scheduled job はここでは実装・仕様化しません。

## 正本として見る current workflow

current repo では `.github/workflows/build-docs.yml` の `build-docs` job が、Docusaurus build、manifest 生成、artifact archive、必要条件を満たす場合の Rails import API 呼び出しを担当します。

運用時の確認順は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) を正本にします。このメモは、その runbook に出てくる `docs-site` artifact と `publish/manifest/publish.json` の metadata を、将来履歴化するなら何を残してよいかだけに絞ります。

## 代表対象

- 対象: Docusaurus site build
- artifact 名: `docs-site`
- manifest path: `publish/manifest/publish.json`
- artifact 内容: `docusaurus/build`、`attachments`、`publish/manifest`
- 確認目的: どの workflow run / commit / manifest 由来の site build だったかを後から追えるようにする

既存の `GeneratedFileRun` / `GeneratedFileEvent` は、アプリ内の生成ファイル job とその retry / preview を読むための履歴です。`docs-site` artifact は GitHub Actions 側の build artifact なので、同じ UI に載せるか、別履歴として扱うかはこのメモでは決めません。

## 保存してよい metadata

履歴化する場合に保存してよい候補は、current workflow と manifest から追える最小 metadata に限定します。

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
- `artifact_retention_hint`: GitHub Actions artifact retention を表示する場合の短い補助情報

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

`docs-site` artifact の履歴を追加する場合は、少なくとも次を画面や API 上で読み分けられるようにします。

- build は成功したが import API は条件未達で呼ばれていない
- build / manifest / archive / artifact upload のどこで失敗したか
- import API failure が artifact 内容由来か、一時的な URL / token / app 側状態由来か
- replay 候補なのか rebuild 優先なのか
- GitHub Actions artifact retention 内で確認できる情報なのか、アプリ側に保存した metadata なのか

この first slice では、それらを実装しません。将来の履歴化時に、保存する metadata と保存しない raw payload を混ぜないための境界だけを先に固定します。

## follow-up 候補

今回の代表対象に含めないものは、必要になった時点で別 issue に分けます。

- search index rebuild の履歴
- import build handoff の履歴
- replay / rebuild の実行導線
- alert / notification / scheduled job
- artifact retention policy の最終決定
- long-term artifact storage
- `GeneratedFileRun` / `GeneratedFileEvent` との UI 統合

## 確認観点

- このメモは docs / proposal 境界であり、DB schema、controller、route、view、background job は変更しない
- `docs-site` artifact 以外の代表対象を同時に増やさない
- secret-like value や private path を保存・表示対象として扱わない
- current workflow の metadata 名は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) と [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md) に戻って確認する
