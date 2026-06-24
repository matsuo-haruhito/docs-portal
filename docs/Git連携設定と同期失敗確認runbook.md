# Git連携設定と同期失敗確認 runbook

この文書は issue `#627` に対応する、`docs-portal` の Git 連携インポート運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、次の 2 画面が Git 連携の確認入口です。

- `Git連携`: `admin/git_import_sources`
- `Git同期履歴`: `admin/git_import_runs`

使い分けの基準は次です。

- 取り込み先案件、対象 repository、branch、path、認証方式を登録・見直ししたいときは `Git連携`
- 手動同期を実行したあとに、どの commit を取り込み、どの状態で終わったかを見たいときは `Git同期履歴`

補助入口として、`定期ジョブ` の詳細で `sync_git_import_sources` を開くと `Git pull同期の運用状態` が表示されます。このカードでは、有効な Git 連携元数、Git import preview build 状態の件数、Git 連携元一覧、直近の pull 型 Git 同期履歴を同じ画面で確認できます。カード内の `Git連携設定` / `Git同期履歴` はそれぞれの正本画面へ戻るための導線であり、定期ジョブ詳細だけで同期設定の修正、履歴の全件検索、再同期判断を完結させる画面ではありません。

`Git pull同期の運用状態` の空状態は、次のように読み分けます。`Git連携元はまだ登録されていません。` は同期元設定が 0 件の初回状態で、`Git連携設定` から登録を始めます。`登録済みのGit連携元はありますが、有効な設定がありません。` は設定自体はあるが全件無効なので、利用する同期元を `Git連携設定` で有効化します。`Git同期履歴はまだありません。` は登録・有効化後に同期がまだ走っていない状態で、同期実行後に `Git同期履歴` で結果を見返します。これらは同期 runner、即時実行、preview build 集計、履歴検索の仕様変更を意味しません。

Git 連携で後続 provider に渡す基準契約は、同期元設定、run 履歴、manifest 化、summary_json、削除候補です。repository / branch / path / commit は Git 専用の入力と revision として扱い、Google Drive / SharePoint の folder ID や delta token とは混ぜません。

## 2. 最初の切り分け順

1. Git 連携設定そのものがあるかを `Git連携` 一覧で確認する
2. 設定がなければ、案件・repository・branch・取込元パスを登録する
3. 設定はあるが `最終同期` が `未同期` のままなら、まず `手動同期` を実行する
4. 同期を実行したあとに状態や失敗理由を追いたいときは `Git同期履歴` を見る

`sync_git_import_sources` の定期ジョブ詳細を開いている場合は、`Git pull同期の運用状態` で有効な連携元数と直近 pull 履歴を先に見て、異常の入口が「設定なし / 無効設定」なのか「履歴上の failed / skipped」なのかを切り分けます。設定値を直すときは `Git連携`、個別 run の commit や error preview を追うときは `Git同期履歴` へ進みます。

定期ジョブ詳細で `Git連携元 0 件` のときは、まず `Git連携設定` で同期元を登録します。`全 N 件` なのに `有効 0 件` のときは、登録済み設定の `状態` を見直して利用する同期元を有効化します。`直近のGit同期履歴` が 0 件でも、それだけで失敗や正常保証とは扱わず、登録・有効化後に手動同期または定期実行で履歴が作られてから `Git同期履歴` で結果を確認します。

## 3. `Git連携` 画面で見ること

### 新規登録・編集で決める項目

`Git連携` 画面の form では、少なくとも次を確認します。

- `案件`: 取り込み先 Project
- `リポジトリ`: `owner/repo` 形式の repository 名
- `ブランチ`: 取り込み対象 branch
- `取込元パス`: 取り込み対象ディレクトリ。初期値は `docs`
- `認証方式`: 通常は `GitHub App` を使う
- `状態`: 一時停止したい場合だけ `無効` にする

詳細設定は current form の summary どおり、通常は開かない管理者・検証向けの領域です。`installation_id`、`credential_ref`、`credential_secret` は、GitHub App 導入前の検証や管理者の調整が必要な場合だけ確認します。通常運用は `GitHub App` 前提で、`fine_grained_pat` は開発・検証用の詳細設定、`no_auth` は公開 repository 用として扱います。

current validation では、新規作成時に `fine_grained_pat` を選ぶ場合だけ `credential_secret` が必須です。編集時の保存済み secret は form に表示されず、空欄のまま保存すると既存値を維持し、新しい値を入力したときだけ更新します。GitHub App や公開 repository の `no_auth` では secret 欄は空欄のまま保存できます。GitHub App installation token 発行、repository 一覧取得、branch / path picker は未実装なので、運用上は入力値と同期履歴で切り分けます。

### 一覧で見返す項目

一覧では次を確認します。

- `案件`: 案件名と project code
- `リポジトリ`: 同期元 repository
- `ブランチ/パス`: どの branch と path を取り込むか
- `認証方式`: `GitHub App` か、検証用の PAT か、公開 repository 用の認証なし設定か
- `最終同期`: 直近で取り込んだ commit と日時
- `状態`: 設定が有効か無効か

`手動同期` を押すと、その設定に対して pull 型同期を実行し、完了後は `Git同期履歴` へ戻ります。同期失敗時は一覧へ戻り、alert に失敗理由が出ます。

押下前の confirmation には repository に加えて branch と取込元パスが表示されます。取込元パスが空の場合は root 相当として `/` を読み返します。この confirmation は同期対象の最終確認であり、手動同期 preview、dry-run、GitImportRun の事前作成、credential 検証、履歴 filter 変更を行う画面ではありません。

## 4. `Git同期履歴` 画面で見ること

`Git同期履歴` に履歴がある場合、画面上部の filter で `状態`、`リポジトリ`、`ブランチ`、`取込元パス`、`コミット` を絞り込めます。`リポジトリ` は `owner/repo` の一部一致、`ブランチ` と `取込元パス` も一部一致で探します。`コミット` は commit SHA の先頭一致で探します。これらの条件は AND 条件で併用され、絞り込み後も表示対象は最新 100 件までです。repository や branch / path を短くしすぎると複数の履歴が混ざり、長くしすぎると 0 件になりやすいため、filtered empty state では適用中の条件を読み返して検索語を短くするか、`絞り込み解除` で最新 100 件表示へ戻します。

### 0件のときの読み方

`Git同期履歴` が 0 件のとき、current UI では空 table や表示設定は出ず、`まだGit同期履歴はありません。` という empty state が出ます。

この状態は「失敗して履歴が消えた」という意味ではなく、まだ手動同期を実行していないか、履歴を作る前の初回状態であることを表します。次の順で見直します。

1. `Git連携` に対象案件・repository・branch・取込元パスが登録されているか確認する
2. 対象設定の `手動同期` を実行する
3. 実行後にこの画面へ戻り、最新の run を確認する

この画面は、同期結果やエラー内容をあとから見返すための履歴面です。初回セットアップそのものは `Git連携` を入口にします。

履歴が 1 件以上ある状態で、状態、repository、branch、取込元パス、commit の絞り込み結果だけが 0 件になると、`条件に一致するGit同期履歴はありません。` という filtered empty state が出ます。この場合は、適用中の状態や各検索条件を読み、必要なら `絞り込み解除` の button-style action で条件を外して最新 100 件表示へ戻します。repository / branch / source path は一部一致、commit は SHA prefix match なので、`missing-repo` や `deadbeef` のように合わない値や狭すぎる値では 0 件になり、検索語や prefix を短くすると見つかる場合があります。

`絞り込み解除` は表示条件を reset するための導線であり、同期 retry、失敗解消、対象なし保証、GitImportRun の保存内容変更を行う操作ではありません。filtered empty state で 0 件でも、別の状態、repository、branch、path、commit には履歴が残っている可能性があります。

### 履歴が1件以上あるときに見返す項目

`Git同期履歴` では、各 run ごとに次を確認します。

- `実行日時`: いつ同期したか
- `案件`: どの Project に対する同期か
- `リポジトリ`: 対象 repository
- `ブランチ/パス`: どの branch / path を読んだか
- `コミット`: 取り込み対象 commit。未取得なら `未取得`
- `状態`: sync の到達状態
- `実行結果`: `summary_json の要約` で、取り込み文書、添付、取込元パス、commit、skip reason、PublishJob、削除候補数を見る。要約できる行がない場合は `summary_json の要約なし`、`summary_json` 自体がない場合は `summary_json なし` と表示される
- `実行結果` の `summary_json のマスク済み詳細`: `summary_json` の safe preview。要約だけでは足りないときに開く
- `エラー`: failure 時の `error_message のマスク済み preview` を確認する。エラーがない run は `エラーなし` と表示される

この画面は run 単位の履歴なので、同じ設定を何度同期したか、どの commit で `skipped` になったかも追えます。`実行結果` の詳細は `summary_json のマスク済み詳細` として表示され、token / secret / authorization、private-looking path 風の値は raw のまま読む前提ではありません。`エラー` も `error_message` の safe preview であり、完全な raw log ではありません。repository、branch、取込元 path、commit、status、skip reason など一次切り分けに必要な情報を先に見て、preview だけで足りない場合は保存値や同期処理をこの画面で再定義せず、対象 repository / branch / path と実行ログの文脈へ戻します。

## 5. status の読み方

`GitImportRun` の current status は次です。

- `pending`: run が作られ、まだ処理前の状態
- `running`: fetch / manifest build / import の途中
- `imported`: 取り込み完了。`GitImportSource` の `last_synced_commit_sha` と `last_synced_at` も更新される
- `skipped`: すでに同期済みの commit、または対象文書なしなどで、新しい取り込みを作らなかった状態
- `failed`: 同期処理が失敗した状態。`エラー` の safe preview と、repository / branch / 取込元パスの入力を合わせて見る

## 6. よくある見直しポイント

### `最終同期` がずっと `未同期`

設定保存までは完了していても、手動同期をまだ実行していない可能性があります。まず `Git連携` 一覧から `手動同期` を押し、その後に `Git同期履歴` の最新行を確認します。`Git同期履歴` がまだ 0 件なら、empty state の案内どおり `Git連携` の設定内容から見直します。

### `skipped` が続く

current implementation では、同じ commit SHA が既に同期済みなら `skipped` として記録します。repository 側に新しい commit がないか、対象 branch / path が意図どおりかを見直します。`reason: no_documents` の場合は、対象 path 配下に取り込み対象の Markdown / MDX があるかを先に確認します。

### `failed` で止まった

`Git同期履歴` の `エラー` を先に確認します。`エラー` は調査入口の safe preview であり、token-like value、authorization header、secret key、private-looking path 風の断片は mask / truncation されます。認証方式、repository 名、branch、取込元パスの入力ミスや credential 不足は、この preview と `Git連携` の設定値を突き合わせて追うのが最短です。

### `summary_json` に削除候補が出た

既存仕様どおり、Git 側で消えたファイルは即 delete されず、削除候補として記録されます。runbook では current behavior の説明に留め、archive / delete の新ルールは追加しません。

## 7. current support の境界

- current provider は `github` のみです
- current flow は `pull` 型の手動同期が中心です
- GitHub App は通常運用の認証方式、Fine-grained PAT は開発・検証用、`no_auth` は公開 repository 用です
- 詳細設定は通常開かない管理者・検証向けで、保存済み secret は form に表示されません。空欄保存は既存 secret 維持、新しい値を入力したときだけ更新です
- `手動同期` confirmation は repository / branch / 取込元パスを押下前に読み返す cue であり、手動同期 preview や dry-run ではありません
- `Git同期履歴` の filter は、状態、repository 一部一致、branch 一部一致、source path 一部一致、commit SHA prefix match を AND 条件で扱い、絞り込み後も最新 100 件までを表示します。project filter、pagination、CSV export は current support ではありません
- `summary_json` と `error_message` の保存値や Git import pipeline は、この runbook の safe preview 説明では変更しません
- `sync_git_import_sources` の定期ジョブ詳細に出る `Git pull同期の運用状態` は read-only な集約表示です。Git連携元が未登録なら `Git連携設定` で登録し、全件無効なら利用する同期元を有効化し、履歴 0 件なら同期実行後に `Git同期履歴` を確認します。同期設定の編集、履歴の全件検索、手動同期、再同期判断は `Git連携` / `Git同期履歴` の正本画面で扱います
- Webhook 自動同期、定期同期、repository 一覧取得、branch / path picker、Git 側削除の自動 archive / delete は、既存仕様でも未対応のままです
- Google Drive / SharePoint / OneDrive の同期本体は、この Git 連携 runbook では扱いません

`Git連携インポート` の仕様文書は「何を取り込むか」の正本で、この runbook は「管理画面でどこを見返すか」の補助です。

## 8. 関連文書

- [Git連携インポート](./Git連携インポート.md)
- [importと変更系dry-run](./specs/importと変更系dry-run.md)
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [README](../README.md)
- [docs/README](./README.md)
