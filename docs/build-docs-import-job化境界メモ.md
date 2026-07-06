# build-docs import job 化境界メモ

このメモは issue `#4738` の first slice として、import / build job 化へ進む前に、代表対象を `build-docs` workflow だけへ固定し、置き換え対象、履歴保存境界、replay / rebuild / human decision の分岐を整理します。

ここでは job 化実装、workflow 条件変更、Rails import API contract 変更、`GeneratedFileRun` schema 変更は行いません。既存 runbook の読み方をそろえ、次に実装 Issue へ分ける条件だけを明確にします。

## 正本として見る文書

- 現在の CI / artifact / Rails import API 呼び出し条件は [build-docs workflow確認runbook](./build-docs%20workflow確認runbook.md) を見る
- `GeneratedFileRun` へ残る site build artifact evidence は [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md) を見る
- 保存してよい metadata と保存しない raw payload は [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) を見る
- 将来候補の棚卸し入口は [ToDo](./ToDo.md) の `Job / 運用自動化` を見る

## この slice の代表対象

対象は `.github/workflows/build-docs.yml` の `build-docs` job だけです。Git連携 run、ZIP import dry-run、external folder sync、mail、webhook、search index rebuild へは広げません。

current workflow の範囲は次の読み方に固定します。

- Docusaurus build、manifest 生成、archive、artifact upload は current `build-docs` job の処理として扱う
- Rails import API 呼び出しは、`main` push かつ import URL / token がある場合だけ走る conditional step として扱う
- 通常 human PR で `build-docs` job が skipped の場合は、未実行であり、成功済みとも failure とも扱わない
- import API failure 後に見る evidence は `docs-site` artifact と `publish/manifest/publish.json` の metadata であり、raw CI log や import payload 全文ではない

## 置き換え候補と現状維持の切り分け

job 化や replay 化を検討するときは、まず何を置き換えるのかを次の単位で分けます。

| 分類 | この slice での扱い | 次に必要な判断 |
| --- | --- | --- |
| `Call Rails import API` failure 後の再取り込み判断 | docs 上で replay 候補 / rebuild 優先 / human decision を分ける | 実行導線を作るなら別 Issue で idempotency と二重実行 guard を決める |
| `GeneratedFileRun` の site build artifact metadata | current support として読み、既存 metadata 名を正本にする | 新しい import attempt metadata と混同しない |
| import attempt metadata | proposal として扱い、保存対象を先取りしない | status、attempt id、request target、safe summary などを保存するか別 Issue で決める |
| artifact 本体 / manifest 全文 / CI log / import API payload | 保存対象外として扱う | retention、access control、長期保存が必要なら人間判断へ戻す |
| Git連携 run / ZIP import dry-run / external folder sync | 対象外 | それぞれの既存 runbook / 履歴境界から別 Issue に切る |

## replay / rebuild / human decision の分岐

`Call Rails import API` step が失敗したときは、すぐ自動 replay せず、次の分岐として読む。

### replay 候補

同じ `docs-site` artifact と同じ `publish/manifest/publish.json` を使うことが安全に説明できる場合だけ、replay 候補にする。

- `artifact.source_commit_hash` が再取り込みしたい commit と一致している
- `artifact.workflow_run_id` と `artifact.workflow_run_attempt` から対象 run を特定できる
- `artifact.manifest_path` が `publish/manifest/publish.json` のまま
- Docusaurus build output、attachments、manifest が artifact 内で揃っている
- 失敗原因が import URL / token / 一時的な network / Rails app 側の一時停止など、artifact 内容と無関係だと説明できる

### rebuild 優先

同じ artifact を使うより、source から作り直す方が安全な場合は rebuild を優先する。

- source commit が進んでいる、または replay したい commit が曖昧
- `publish/documents.json`、attachments、Docusaurus source、manifest 生成 script を修正済み
- manifest schema や Rails import API 側の解釈が変わっている
- artifact retention が切れている、または権限上取得できない
- artifact 内容の欠落、manifest validation、build output の不整合が失敗原因に含まれる

### human decision へ戻す

次の判断が必要な場合は、Quality Fixer / Docs Fixer だけで実装へ進めず、人間判断へ戻す。

- import attempt metadata をアプリ側 DB に保存するか
- artifact 本体、manifest 全文、CI log、import API payload を長期保存するか
- replay を UI、task、workflow_dispatch、manual run のどこから起動するか
- automatic retry、notification、SLA、alert rule を採用するか
- Git連携 run、ZIP import dry-run、external folder sync へ横展開するか

## metadata の混同を避ける

current support の `GeneratedFileRun` は、site build artifact の read-only evidence を残すための履歴です。保存済み metadata は artifact 名、source repo / branch / commit、workflow run id / attempt、manifest path、manifest document count に限定します。

将来検討する import attempt metadata は、Rails import API 呼び出し自体の attempt をどう追うかという別の proposal です。`GeneratedFileRun` に既に残る site build artifact evidence を、import request payload や retry state の保存済み contract として読まないでください。

## 実装 Issue に切る条件

次に実装 Issue へ進める場合は、少なくとも次を 1 Issue に 1 つずつ固定します。

- 対象 workflow または対象 import surface
- replay / rebuild / human decision のどれを実装するか
- 保存する metadata allowlist と保存しない raw payload
- idempotency、二重実行、既存 import 結果への影響
- 実行導線と権限境界
- request spec、job spec、docs-quality guard のどれで守るか

この条件が揃うまでは、current docs では planning boundary として扱い、job 化実装や automatic retry policy を先取りしません。
