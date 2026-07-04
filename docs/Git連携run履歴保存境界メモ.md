# Git連携 run 履歴保存境界メモ

このメモは issue `#4604` の first slice として、Git連携 run を job 化や履歴保存拡張へ進める前に、current support と proposal / follow-up の境界を 1 workflow に絞って確認するための境界メモです。

対象は `Git連携`、`Git同期履歴`、`sync_git_import_sources` 定期ジョブ詳細で確認できる Git 連携 run だけです。Git import runner の job 化、`GitImportRun` schema 変更、credential policy、branch / path picker、Git 側削除候補の archive / delete 実装はこのメモでは扱いません。

## 正本として見る current surface

current repo では、Git連携 run の運用確認は次の 3 つに分かれています。

- `Git連携`: `admin/git_import_sources`。同期元 Project、repository、branch、取込元 path、認証方式、状態、最終同期を確認する
- `Git同期履歴`: `admin/git_import_runs`。run 単位の repository、branch、source path、commit、status、summary_json safe preview、error_message safe preview を確認する
- `sync_git_import_sources` 定期ジョブ詳細: `Git pull同期の運用状態` として、有効な連携元数、Git import preview build 状態、直近 pull 履歴への read-only な入口を確認する

運用時の確認順は [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md) を正本にします。このメモは、その runbook に出てくる Git連携 run を将来履歴化・job 化するときの保存境界だけに絞ります。

## current support

現在の Git連携 run は、設定、手動同期、定期ジョブ詳細、run 履歴を同じ workflow として読み分けます。

- 手動同期は `Git連携` の設定 1 件に対して pull 型同期を実行する入口
- 定期同期は `sync_git_import_sources` が有効な Git 連携元を拾う入口
- `Git同期履歴` は同期実行後に run 単位で commit、status、summary、error preview を見返す入口
- 定期ジョブ詳細の `Git pull同期の運用状態` は read-only な集約表示であり、同期設定の修正、履歴の全件検索、再同期判断を完結させる画面ではない

この first slice では、Git連携 run を `GeneratedFileRun` に統合することも、既存 `GitImportRun` を置き換えることも current support として扱いません。

## 保存してよい metadata 候補

将来 Git連携 run を別の read-only evidence に寄せる場合でも、保存候補は運用上の切り分けに必要な短い metadata に限定します。

- `status`: Git import run の到達状態
- `started_at` / `finished_at`: run の開始・終了時刻が観測できる場合の時刻
- `project_code` または project public identifier
- `repository`: `owner/repo` 形式の同期元 repository
- `branch`: 取り込み対象 branch
- `source_path`: 取り込み対象 path
- `commit_sha`: 取り込み対象 commit
- `source_id` または `git_import_source` の短い識別子
- `summary_counts`: 取り込み文書数、添付数、skip reason、削除候補数などの集計値
- `error_summary`: mask / truncate 済みの短い error preview

保存するときは、既存 runbook の `summary_json の要約` と `error_message のマスク済み preview` の境界を優先します。詳細な raw payload が必要な場合は、履歴保存先を広げるのではなく、対象 repository、branch、path、commit、実行ログの文脈へ戻ります。

## 保存しない raw payload

次の値は Git連携 run の履歴として長期保存しません。必要なときは、権限のある repository / workflow / app log の範囲で都度確認します。

- raw clone log 全文
- credential、access token、authorization header、secret-like value
- repository contents の全文
- manifest 全文や import API payload 全文
- private-looking absolute path
- provider API response 全文
- CI log / job log 全文
- GitHub App installation token や PAT の値
- 削除候補 apply の raw payload

Git連携 run の履歴は、再実行・再同期・削除適用・credential 検証の承認記録ではありません。保存境界が広がる場合は、credential / repository contents / raw log を含めない別 issue として扱います。

## site build artifact 履歴との比較

[site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) は、`docs-site` artifact と `publish/manifest/publish.json` の read-only evidence を `GeneratedFileRun` に保存する current support を扱います。

Git連携 run は似た形で source repo / branch / commit / path を持ちますが、site build artifact とは次が異なります。

- site build artifact は GitHub Actions artifact と manifest metadata が代表対象で、Git連携 run は app 側の import source と pull/import result が代表対象
- site build artifact は artifact 名、workflow run id、manifest path が中心で、Git連携 run は repository、branch、source path、commit、summary_json / error preview が中心
- site build artifact の current implementation は `GeneratedFileRun` recorder を持つが、Git連携 run は既存 `GitImportRun` を current source of truth とする
- site build artifact の履歴化は artifact 本体や manifest 全文を保存しない境界で進んでいるが、Git連携 run では raw clone log、repository contents、credential、manifest 全文を保存しない境界を別に守る必要がある

このため、site build artifact の考え方は metadata allowlist と raw payload 非保存の方針だけを流用し、Git連携 run の保存先や schema は流用済みと扱いません。

## follow-up 候補

この first slice に含めないものは、必要になった時点で別 issue に分けます。

- Git import runner の job 化
- `GitImportRun` schema の変更
- `GeneratedFileRun` への統合または read-only evidence 追加
- retry / replay / alert / scheduled job の追加
- branch picker / path picker / repository picker の拡張
- Git 側削除候補の archive / delete 実装
- credential policy / GitHub App installation policy の変更

## 確認観点

- 手動同期、定期同期、run 履歴、read-only evidence を同じ実装変更として混ぜない
- 保存してよい metadata と保存しない raw payload を分ける
- `Git連携` 設定一覧の project / repository / branch / path と `Git同期履歴` の run filter を混同しない
- site build artifact 履歴の current support を、Git連携 run の current implementation として先取りしない
- Git import runner、credential、repository picker、branch / path picker、削除候補 apply を同時に変更しない
