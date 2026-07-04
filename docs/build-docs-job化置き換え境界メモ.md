# build-docs job 化置き換え境界メモ

このメモは issue `#4585` の first slice として、`.github/workflows/build-docs.yml` の `build-docs` job を将来 Rails app 側 job へ置き換えるか検討するときの棚卸し境界を整理します。

ここでは job 実装、queue contract、DB schema、workflow redesign、retry / replay、alert、scheduled job は定義しません。current workflow の事実をもとに、GitHub Actions に残す候補、Rails app 側 job 化候補、履歴保存 metadata、保存しない raw payload を分けます。

## 正本

- current workflow: `.github/workflows/build-docs.yml` の `build-docs` job
- 運用確認順: [build-docs workflow確認runbook](./build-docs%20workflow確認runbook.md)
- current metadata 保存境界: [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md)
- manifest 仕様: [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md)

## 対象を 1 workflow に固定する

この first slice の対象は `build-docs` job だけです。

含めるもの:

- Docusaurus dependency install
- Docusaurus build
- `publish/manifest/publish.json` 生成
- `docs-site.tar.gz` archive
- `docs-site` artifact upload
- 条件付き Rails import API call

含めないもの:

- `test` job / `seed-smoke` job / `security-audit` job の redesign
- Git連携 run / ZIP import dry-run / external folder sync の job 化
- search index rebuild 履歴
- Rails app 側 queue / worker / model / DB schema 実装
- replay / rebuild UI、alert、notification、scheduled job

## step ごとの置き換え候補

| current step | current での役割 | GitHub Actions に残す候補 | Rails app 側 job 化候補 | first slice の判断 |
| --- | --- | --- | --- | --- |
| `Install Docusaurus dependencies` | `docusaurus/package-lock.json` に基づき build 依存を準備する | GitHub Actions の Node cache / npm install として残す | app 側で build worker を持つ場合だけ候補 | まだ移さない。依存 install の失敗は workflow evidence として読む |
| `Build Docusaurus site` | `docusaurus/build` を生成する | source repo の build job として残す | app 側で source checkout と build 環境を持つ場合だけ候補 | current support は GitHub Actions build |
| `Create manifest` | `publish/documents.json` から `publish/manifest/publish.json` を作る | build artifact と同じ run の metadata として残す | import 前 validation を app 側で再実行する場合の候補 | manifest 生成は current workflow の正本として扱う |
| `Archive build output` | `docusaurus/build`、`attachments`、`publish/manifest` を `docs-site.tar.gz` にまとめる | artifact evidence として残す | app 側が artifact を直接作るなら候補 | current support は `docs-site` artifact |
| `Upload artifact` | GitHub Actions artifact `docs-site` として保存する | run evidence / short retention の保存先として残す | app 側 long-term storage を採用する場合だけ候補 | #3636 の current metadata 保存と重複させない |
| `Call Rails import API` | `main` push かつ import URL / token がある場合だけ app に import を依頼する | source repo からの handoff として残す | app 側 queue が pull / fetch / import する場合の候補 | token / endpoint / payload 保存の判断はここではしない |

## 保存してよい metadata 候補

将来 job 化や履歴保存を検討するときも、保存候補は短い識別情報に限定します。

- workflow name / job name: `ci` / `build-docs`
- source repository / branch / commit SHA
- workflow run id / run attempt
- artifact name: `docs-site`
- manifest path: `publish/manifest/publish.json`
- build status / started_at / finished_at
- manifest document count など、本文や payload を含まない集計値
- import API call が条件未達だったか、呼び出し後に失敗したかの短い状態

## 保存しない raw payload

次は Rails app 側履歴や docs evidence にそのまま保存しません。

- `RAILS_PORTAL_IMPORT_TOKEN`、secret、Authorization header
- import API request payload 全文
- `docs-site.tar.gz` 本体
- `publish/manifest/publish.json` 全文の長期保存
- `attachments/` 配下のファイル本文
- Docusaurus build log / CI log 全文
- raw absolute path、runner workspace path、local private path
- customer document body、preview HTML 全文、raw provider metadata

raw payload が必要な場合は、artifact / workflow run の権限内で都度確認します。長期保存、retention、閲覧権限、外部 storage 連携は人間判断が必要な別 issue に分けます。

## current metadata 保存との分担

[site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) は、`docs-site` artifact の read-only evidence を `GeneratedFileRun` に残す current support を扱います。

このメモは、その current support を置き換えるものではありません。役割は次のように分けます。

- current support: `docs-site` artifact がどの workflow run / commit / manifest 由来かを `GeneratedFileRun` で追う
- #4585 の棚卸し: 将来 `build-docs` job を Rails app 側 job 化する場合、どの step を移す候補にするか、どの metadata だけを保存候補にするかを整理する
- 後続実装 issue: queue、worker、schema、retry / replay、alert、retention、UI を採用するかを個別に判断する

## 後続 issue に分ける条件

次のどれかを実装したくなった時点で、このメモから別 issue に分けます。

- Rails app 側で Docusaurus build を実行する
- app 側 queue / worker / DB model を追加する
- GitHub Actions artifact 以外へ long-term storage する
- import API call を app 側 pull 型に置き換える
- replay / rebuild UI を追加する
- alert / notification / scheduled job を追加する
- artifact retention policy や閲覧権限を決める

## 確認観点

- 対象を `build-docs` job だけに閉じているか
- `docs-site` artifact metadata の current support と、将来 job 化の proposal を混ぜていないか
- GitHub Actions に残す候補と Rails app 側 job 化候補を分けているか
- raw payload、secret、artifact body、CI log 全文を保存候補にしていないか
- replay / rebuild / alert / scheduled job の採否をこの docs-only slice で決めていないか
