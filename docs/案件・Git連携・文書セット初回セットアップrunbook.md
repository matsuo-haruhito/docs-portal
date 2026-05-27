# 案件・Git連携・文書セット初回セットアップrunbook

この runbook は、internal admin が current `main` の管理画面で 0 件から案件公開の土台を作るときの順序をまとめる。

新しい運用ルールはここでは定義しない。current route、form、既存 runbook を前提に、「最初の 1 件をどこから作るか」と「次に戻る画面」を整理する。

## この runbook が扱う画面

- `案件`: `/admin/projects`
- `Git連携`: `/admin/git_import_sources`
- `Git同期履歴`: `/admin/git_import_runs`
- `文書セット`: `/admin/document_sets`

## 先に知っておくこと

- 3 画面とも internal admin 向けの `/admin` 配下にある。`company_master_admin` が見られる画面境界は [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md) を正本にする。
- `文書セット` は、対象案件に文書が取り込まれてから初めて `対象文書` を選べる。最初の 1 件は `案件` と `Git連携` を先に整える方が迷いにくい。
- Git 以外の経路で文書を入れる場合は、[ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)、[ZIPインポートdry-run運用runbook](./ZIPインポートdry-run運用runbook.md)、[internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md) を使い、文書が入ってから `文書セット` へ戻る。

## まず見る順序

1. `案件` で取り込み先の Project を作る
2. `Git連携` で repository / branch / path を登録する
3. `手動同期` の結果を `Git同期履歴` で確認する
4. 文書が入ったあとに `文書セット` を作る

## 1. `案件` で最初の Project を作る

`/admin/projects` の上段 `新規登録` が入口。current form では少なくとも次の項目を見ればよい。

- `コード`
- `案件名`
- `企業`
- `有効`
- `説明`

current form copy では `企業` は `企業を選択（未設定可）` になっているので、会社ひも付けを後回しにしたい案件でも先に Project 自体は作り始められる。

登録後にまず確認すること:

- 一覧に `コード` と `案件名` が出ているか
- `状態` が intended な `有効` / `無効` になっているか
- このあと Git 連携や文書セットで選びたい案件として見えるか

ここで Project ができたら、文書の流入経路に応じて次へ進む。

- GitHub repository から pull 型で取り込みたい: `Git連携` へ進む
- すでに seed / ZIP / internal upload で文書を持ち込む前提がある: その import を済ませてから `文書セット` へ進む

## 2. `Git連携` で最小構成を登録する

`/admin/git_import_sources` の上段には、`GitHubリポジトリからpull型で取り込む` という説明 card と `新規登録` form がある。初回は form の次の項目を順に見る。

- `案件`: どの Project へ取り込むか
- `リポジトリ`: `owner/repo` 形式
- `ブランチ`
- `取込元パス`
- `認証方式`
- `状態`

current controller の初期値は次のとおり。

- `ブランチ`: `main`
- `取込元パス`: `docs`
- `認証方式`: `github_app`
- `状態`: `有効`

通常運用では current form copy のとおり `GitHub App` を優先する。`provider`、`Organization`、`installation_id`、`credential_ref`、`credential_secret` は `詳細設定（管理者・検証向け）` にまとまっているので、初回は必要になったときだけ開けばよい。

登録後に進む順序:

1. 一覧へ戻って `案件`、`リポジトリ`、`ブランチ/パス` が意図どおりか確認する
2. `手動同期` を実行する
3. redirect 先の `Git同期履歴` で最新 run の `状態`、`コミット`、`エラー` を見る
4. 必要なら `Git連携` 一覧へ戻り、`最終同期` が更新されたか確認する

`最終同期` が `未同期` のままなら、まだ初回取り込みが完了していない。`文書セット` に進む前に、まず [Git連携設定と同期失敗確認runbook](./Git連携設定と同期失敗確認runbook.md) で branch / path / 認証方式 / エラー内容を見直す。

## 3. `文書セット` は文書が入ってから作る

`/admin/document_sets` も上段 `新規登録` form が入口。current form では次の項目を見れば、最初の 1 件は作り始められる。

- `案件`
- `名称`
- `種別`
- `公開範囲`
- `表示順`
- `説明`

`案件` を選んだあと、対象案件に文書が入っていれば `対象文書` table が現れ、次を調整できる。

- どの文書をセットに含めるか
- 特定版で固定するか、`最新版を使う` か
- `並び順`
- `メモ`

current code では、案件を選んでもその案件に文書がまだ 0 件なら `対象文書` table は出ず、form 下部には `案件を選ぶと対象文書を設定できます。` という補助文だけが残る。初回セットアップでここに来て詰まったら、文書セット画面の入力ミスと決めつけず、先に次を見直す。

- `Git連携` の `手動同期` をまだ実行していないか
- `Git同期履歴` が `failed` / `skipped` で止まっていないか
- branch や `取込元パス` が intended な文書ディレクトリを向いているか
- Git 以外の import を使う案件なら、その import がまだ終わっていないだけではないか

文書セット登録後に確認すること:

- 一覧に `案件`、`名称`、`種別`、`公開範囲`、`文書数` が出るか
- `文書数` が選んだ対象と大きくずれていないか
- 初回 0 件状態では `文書セット一覧の表示設定` より上段 form の方が主導線になることをチーム内でも共有できているか

## よくある詰まりどころ

### `案件` は作れたが `文書セット` に対象文書が出ない

current code では、文書が 1 件も無い案件では `対象文書` table が出ない。まず `Git連携` と `Git同期履歴` を確認し、取り込みが完了してから戻る。

### `Git連携` を作ったのに `最終同期` が `未同期` のまま

設定保存と文書取り込みは別。`手動同期` を実行し、その結果を `Git同期履歴` で確認する。

### どの import 経路で文書を入れるかが Git 以外かもしれない

この runbook は順序整理が目的で、import 方式の優劣は決めない。Git を使わない案件では、[ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)、[ZIPインポートdry-run運用runbook](./ZIPインポートdry-run運用runbook.md)、[internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md) のどれが current flow に合うかを先に決める。

### 会社やユーザーの整備も一緒に必要

`案件` 作成時の `企業` 選択や、その後の user 整備まで含めたいときは [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md) へ戻る。案件への参加や公開範囲まで見直すなら [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md) を使う。

## 関連文書

- [Git連携設定と同期失敗確認runbook](./Git連携設定と同期失敗確認runbook.md)
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [ZIPインポートdry-run運用runbook](./ZIPインポートdry-run運用runbook.md)
- [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md)
- [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md)
- [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md)
- [README](../README.md)
- [docs/README](./README.md)