# ZIPインポートdry-run 履歴保存境界メモ

このメモは issue `#4619` の first slice として、ZIP import dry-run を job 化や履歴保存拡張へ進める前に、current support と proposal / follow-up の境界を 1 workflow に絞って確認するための境界メモです。

対象は `ZIPインポート` と `ZIPインポートdry-run` で確認できる `admin/zip_imports` workflow だけです。ZIP importer の job 化、ZIP parser / importer pipeline、storage policy、retry / replay UI、artifact 長期保存 policy はこのメモでは扱いません。

## 正本として見る current surface

current repo では、ZIP import dry-run の運用確認は次の 3 つに分かれています。

- `ZIPインポート`: `admin/zip_imports/new`。案件、版ラベル、取り込み後ステータス、取り込み元メモ、branch / commit、ZIP ファイルを入力して dry-run を作成する
- `ZIPインポートdry-run`: `admin/zip_imports/:public_id`。状態、dry-run ID、summary count、warning count、TreeView プレビューを見て、取り込み前の最終確認をする
- `この内容で取り込む`: `analyzed` の dry-run だけを confirmed execution の入力として使う

運用時の確認順は [ZIPインポートdry-run運用 runbook](./ZIPインポートdry-run運用runbook.md) を正本にします。このメモは、その runbook に出てくる ZIP dry-run を将来履歴化・job 化するときの保存境界だけに絞ります。

## current support

現在の ZIP import dry-run は、upload、dry-run 作成、detail 確認、confirmed 実行を 1 workflow として読み分けます。

- dry-run 作成は、ZIP ファイルを受け取り、取り込み候補と TreeView preview を確認できる状態を作る入口
- detail 確認は、`analyzed` / `confirmed` / `expired` / `failed` の status、summary count、warning count、TreeView preview を読む入口
- confirmed 実行は、`analyzed` の dry-run を入力にして import を確定する入口
- 再確認したい場合は、同じ dry-run を再実行するのではなく `別のZIPをアップロード` から作り直す前提で見る

この first slice では、ZIP import dry-run を `GeneratedFileRun` に統合することも、ZIP importer の非同期 job 化を current support として扱うこともありません。

## 保存してよい metadata 候補

将来 ZIP import dry-run を別の read-only evidence に寄せる場合でも、保存候補は運用上の切り分けに必要な短い metadata に限定します。

- `import_mode`: `zip`
- `status`: `analyzed` / `confirmed` / `expired` / `failed`
- `project_code` または project public identifier
- `version_label`: 入力された表示用ラベル
- `target_status`: 取り込み後ステータス
- `source_note`: 取り込み元リポジトリ / メモの短い値
- `source_branch`: 入力された branch
- `source_commit`: 入力された commit SHA
- `summary_counts`: 合計、新規、更新、warning count などの集計値
- `created_by` / `confirmed_by`: actor を保存する場合の短い識別子
- `created_at` / `confirmed_at`: dry-run 作成と confirmed 実行の観測時刻
- `dry_run_public_id`: 問い合わせや画面遷移に使う短い識別子

保存するときは、既存 runbook の `取り込み概要` と TreeView プレビューの境界を優先します。詳細な raw payload が必要な場合は、履歴保存先を広げるのではなく、対象 dry-run、upload 元、storage、importer log の権限ある確認へ戻ります。

## 保存しない raw payload

次の値は ZIP import dry-run の履歴として長期保存しません。必要なときは、権限のある storage / artifact / app log の範囲で都度確認します。

- uploaded ZIP 本体
- 展開済み file contents
- generated manifest 全文
- full tree payload / preview JSON 全文
- attachment body、Markdown body、HTML preview 全文
- storage absolute path、runner workspace path、local private path
- credential、token、authorization header、secret-like value
- importer log / CI log / job log 全文
- provider API response 全文

ZIP import dry-run の履歴は、取り込み承認、artifact 長期保存、rollback / cleanup、再実行許可の承認記録ではありません。保存境界が広がる場合は、raw ZIP、展開済み contents、manifest 全文、storage path を含めない別 issue として扱います。

## Git連携 run / site build artifact との比較

[Git連携 run 履歴保存境界メモ](./Git連携run履歴保存境界メモ.md) は、Git連携 run の repository / branch / source path / commit / summary_json / error preview を扱います。

[site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) は、`docs-site` artifact と `publish/manifest/publish.json` の read-only evidence を `GeneratedFileRun` に保存する current support を扱います。

ZIP import dry-run は似た形で source branch / commit や summary count を持ちますが、次が異なります。

- ZIP import dry-run は upload file と dry-run detail が代表対象で、Git連携 run は repository pull / import result が代表対象
- ZIP import dry-run は `ImportDryRun(import_mode=zip)` の status と preview が中心で、site build artifact は workflow run / artifact / manifest metadata が中心
- site build artifact の current implementation は `GeneratedFileRun` recorder を持つが、ZIP import dry-run は existing dry-run detail を current source of truth とする
- Git連携 run では raw clone log / repository contents / credential を保存しない境界を守り、ZIP import dry-run では raw ZIP / 展開済み contents / full tree payload を保存しない境界を守る

このため、既存の境界メモからは metadata allowlist と raw payload 非保存の方針だけを流用し、保存先や schema を流用済みとは扱いません。

## internal upload API dry-run との比較

internal upload API の `artifact_imports` / `zip_uploads` / `file_uploads` は、API 経由で dry-run 作成と apply を分けます。管理画面の ZIP import dry-run は同じ ZIP import pipeline の考え方を共有しますが、運用 surface は `admin/zip_imports` の upload / detail / confirmed 実行です。

- API 側は request payload、token、client upload context を扱う
- admin ZIP import 側は管理画面上の入力値、dry-run detail、TreeView preview、confirmed 実行の読み分けを扱う
- どちらも raw upload body、manifest 全文、credential、storage path を履歴として長期保存しない
- API apply 停止、maintenance mode、token policy はこのメモでは判断しない

## follow-up 候補

この first slice に含めないものは、必要になった時点で別 issue に分けます。

- ZIP importer の非同期 job 化
- `ImportDryRun` schema の変更
- `GeneratedFileRun` への統合または read-only evidence 追加
- retry / replay / alert / scheduled job の追加
- artifact 長期保存 policy の最終決定
- raw ZIP / 展開済み contents / manifest 全文の保存
- storage cleanup / retention policy / rollback の設計
- upload size / file count / ZIP parser policy の変更

## 確認観点

- dry-run 作成、detail 確認、confirmed 実行、作り直し判断を同じ実装変更として混ぜない
- 保存してよい metadata と保存しない raw payload を分ける
- `analyzed` / `confirmed` / `expired` / `failed` の current status を履歴化 proposal と混同しない
- Git連携 run や site build artifact の current implementation を ZIP import dry-run の current implementation として先取りしない
- ZIP importer、storage policy、retry / replay UI、artifact 長期保存 policy を同時に変更しない
