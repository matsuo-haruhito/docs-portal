# Git連携設定と同期失敗確認 runbook

この文書は issue `#627` に対応する、`docs-portal` の Git 連携インポート運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、次の 2 画面が Git 連携の確認入口です。

- `Git連携`: `admin/git_import_sources`
- `Git同期履歴`: `admin/git_import_runs`

使い分けの基準は次です。

- 取り込み先案件、対象 repository、branch、path、認証方式を登録・見直ししたいときは `Git連携`
- 手動同期を実行したあとに、どの commit を取り込み、どの状態で終わったかを見たいときは `Git同期履歴`

Git 連携で後続 provider に渡す基準契約は、同期元設定、run 履歴、manifest 化、summary_json、削除候補です。repository / branch / path / commit は Git 専用の入力と revision として扱い、Google Drive / SharePoint の folder ID や delta token とは混ぜません。

## 2. 最初の切り分け順

1. Git 連携設定そのものがあるかを `Git連携` 一覧で確認する
2. 設定がなければ、案件・repository・branch・取込元パスを登録する
3. 設定はあるが `最終同期` が `未同期` のままなら、まず `手動同期` を実行する
4. 同期を実行したあとに状態や失敗理由を追いたいときは `Git同期履歴` を見る

## 3. `Git連携` 画面で見ること

### 新規登録・編集で決める項目

`Git連携` 画面の form では、少なくとも次を確認します。

- `案件`: 取り込み先 Project
- `リポジトリ`: `owner/repo` 形式の repository 名
- `ブランチ`: 取り込み対象 branch
- `取込元パス`: 取り込み対象ディレクトリ。初期値は `docs`
- `認証方式`: 通常は `GitHub App` を使う
- `状態`: 一時停止したい場合だけ `無効` にする

詳細設定では `installation_id`、`credential_ref`、`credential_secret` を持てますが、current form copy のとおり通常運用は `GitHub App` 前提です。`fine_grained_pat` は開発・検証用の詳細設定として扱います。`no_auth` は公開 repository 用で、private repository には使いません。

current validation では `fine_grained_pat` のときだけ `credential_secret` が必須です。GitHub App installation token 発行、repository 一覧取得、branch / path picker は未実装なので、運用上は入力値と同期履歴で切り分けます。

### 一覧で見返す項目

一覧では次を確認します。

- `案件`: 案件名と project code
- `リポジトリ`: 同期元 repository
- `ブランチ/パス`: どの branch と path を取り込むか
- `認証方式`: `GitHub App` か、検証用の PAT か、公開 repository 用の認証なし設定か
- `最終同期`: 直近で取り込んだ commit と日時
- `状態`: 設定が有効か無効か

`手動同期` を押すと、その設定に対して pull 型同期を実行し、完了後は `Git同期履歴` へ戻ります。同期失敗時は一覧へ戻り、alert に失敗理由が出ます。

## 4. `Git同期履歴` 画面で見ること

### 0件のときの読み方

`Git同期履歴` が 0 件のとき、current UI では空 table や表示設定は出ず、`まだGit同期履歴はありません。` という empty state が出ます。

この状態は「失敗して履歴が消えた」という意味ではなく、まだ手動同期を実行していないか、履歴を作る前の初回状態であることを表します。次の順で見直します。

1. `Git連携` に対象案件・repository・branch・取込元パスが登録されているか確認する
2. 対象設定の `手動同期` を実行する
3. 実行後にこの画面へ戻り、最新の run を確認する

この画面は、同期結果やエラー内容をあとから見返すための履歴面です。初回セットアップそのものは `Git連携` を入口にします。

### 履歴が1件以上あるときに見返す項目

`Git同期履歴` では、各 run ごとに次を確認します。

- `実行日時`: いつ同期したか
- `案件`: どの Project に対する同期か
- `リポジトリ`: 対象 repository
- `ブランチ/パス`: どの branch / path を読んだか
- `コミット`: 取り込み対象 commit。未取得なら `未取得`
- `状態`: sync の到達状態
- `実行結果`: `summary_json` の要約。取り込み文書、添付、取込元パス、commit、skip reason、PublishJob、削除候補数を見る
- `エラー`: failure 時の例外や validation エラーを確認する

この画面は run 単位の履歴なので、同じ設定を何度同期したか、どの commit で `skipped` になったかも追えます。raw `summary_json` は詳細表示で残しておき、要約で読み違えたときに確認します。

## 5. status の読み方

`GitImportRun` の current status は次です。

- `pending`: run が作られ、まだ処理前の状態
- `running`: fetch / manifest build / import の途中
- `imported`: 取り込み完了。`GitImportSource` の `last_synced_commit_sha` と `last_synced_at` も更新される
- `skipped`: すでに同期済みの commit、または対象文書なしなどで、新しい取り込みを作らなかった状態
- `failed`: 同期処理が失敗した状態。`エラー` を見る

## 6. よくある見直しポイント

### `最終同期` がずっと `未同期`

設定保存までは完了していても、手動同期をまだ実行していない可能性があります。まず `Git連携` 一覧から `手動同期` を押し、その後に `Git同期履歴` の最新行を確認します。`Git同期履歴` がまだ 0 件なら、empty state の案内どおり `Git連携` の設定内容から見直します。

### `skipped` が続く

current implementation では、同じ commit SHA が既に同期済みなら `skipped` として記録します。repository 側に新しい commit がないか、対象 branch / path が意図どおりかを見直します。`reason: no_documents` の場合は、対象 path 配下に取り込み対象の Markdown / MDX があるかを先に確認します。

### `failed` で止まった

`Git同期履歴` の `エラー` を先に確認します。認証方式、repository 名、branch、取込元パスの入力ミスや credential 不足は、この画面の失敗理由から追うのが最短です。

### `summary_json` に削除候補が出た

既存仕様どおり、Git 側で消えたファイルは即 delete されず、削除候補として記録されます。runbook では current behavior の説明に留め、archive / delete の新ルールは追加しません。

## 7. current support の境界

- current provider は `github` のみです
- current flow は `pull` 型の手動同期が中心です
- GitHub App は本命認証、Fine-grained PAT は検証用、`no_auth` は公開 repository 用です
- Webhook 自動同期、定期同期、repository 一覧取得、branch / path picker、Git 側削除の自動 archive / delete は、既存仕様でも未対応のままです
- Google Drive / SharePoint / OneDrive の同期本体は、この Git 連携 runbook では扱いません

`Git連携インポート` の仕様文書は「何を取り込むか」の正本で、この runbook は「管理画面でどこを見返すか」の補助です。

## 8. 関連文書

- [Git連携インポート](./Git連携インポート.md)
- [importと変更系dry-run](./specs/importと変更系dry-run.md)
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [README](../README.md)
- [docs/README](./README.md)
