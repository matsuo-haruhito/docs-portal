---
name: "PRライフサイクル"
description: "ローカル検証、PR作成、GitHub CI確認、マージ、マージ後検証を安全に進める"
---
# PRライフサイクル

PR作成からGitHub CI確認、マージ、後片付けまでを一貫して進める。issue解決スキルから呼ばれる場合も、単独で使う場合も同じgateを守る。

## 必須境界

- PR作成前に変更範囲へ対応する targeted test / lint / docs guard を実行する
- ローカルテスト成功をGitHub Actions成功の代替にしない
- GitHub上のrequired checkがgreenになるまでmergeしない
- failed / cancelled / timed out / pendingのcheckがある状態でmergeしない
- CIの待機を打ち切った場合は、mergeせずに未確認checkとrun URLを報告する
- merge後に不具合が見つかっても`main`へ直接修正commitしない。必ず新しいbranchとfollow-up PRを使う
- hookを`--no-verify`で回避しない

## 1. PR前のローカル確認

変更ファイルを確認する。

```bash
git status --short
git diff --check
git diff --name-only
```

影響範囲に応じてtargeted testを実行する。

```bash
bundle exec rspec <関連specファイル>
```

Docker環境の場合:

```bash
docker compose run --rm app bundle exec rspec <関連specファイル>
```

代表的な対応:

- `app/models/xxx.rb` → `spec/models/xxx_spec.rb`
- `app/controllers/xxx_controller.rb` → `spec/requests/xxx_spec.rb`
- `app/controllers/admin/xxx_controller.rb` → `spec/requests/admin_xxx_spec.rb`
- `app/jobs/xxx_job.rb` → `spec/jobs/xxx_job_spec.rb`
- `app/services/xxx.rb` → `spec/services/xxx_spec.rb`
- `app/importers/xxx.rb` → `spec/importers/xxx_spec.rb`
- `app/views/xxx/` → 対応するrequest spec。文言固定ではなくDOM構造、form action、操作可否、link先を確認する
- migration / schema → model・request・seed・schemaの影響対象
- docs / workflow / guard → 対応するdocs-quality scriptとYAML parse

ローカル確認が失敗している状態ではPR作成へ進まない。

## 2. branchをpushしてPRを作成

```bash
git push -u origin HEAD
gh pr create --base main --fill
```

issue解決から呼ばれた場合は、PR本文に`Closes #<number>`が含まれることを確認する。PR本文には次を分けて記録する。

- 実行したローカル検証
- 未実施のbrowser visual evidence
- migration / maintenance / rollback上の注意

## 3. GitHub CIを実際に確認

PR番号とcheck一覧を確認する。

```bash
gh pr view --json number,url,headRefName,statusCheckRollup
gh pr checks <PR番号>
```

check完了を待つ場合:

```bash
gh pr checks <PR番号> --watch --interval 10
```

CIが失敗したら、該当runのfailed logを取得する。

```bash
gh run view <run-id> --log-failed
```

GitHub側障害、runner障害、action download障害も「green」とは扱わない。コード起因か外部障害かを分けて報告し、再実行結果がgreenになるまでmergeしない。

## 4. CI失敗時の修正

- 失敗内容と変更の因果を確認する
- 同じfeature branchで修正する
- targeted testを再実行する
- 修正を新しいcommitとしてpushする
- GitHub Actionsの新しいrunを再確認する

pre-commit hook失敗後は修正して再stageし、新しいcommitを作る。`--amend`や`--no-verify`で隠さない。

## 5. merge gate

次をすべて満たした場合だけmergeする。

- targeted local validationが成功
- required GitHub checksがすべて成功
- unresolved review commentやmerge conflictがない
- migration、maintenance mode、rollbackの未解決事項がない
- browser visual evidence未実施の場合、その事実とfollow-upが明記されている

```bash
gh pr merge <PR番号> --squash --delete-branch
```

## 6. merge後確認

```bash
git checkout main
git pull --ff-only
bin/all_test
```

`tmp/all_test/summary.txt`と失敗stepのlogを確認する。コマンドのexit codeだけでなく、RSpec examples / failures、lint、security、docs guardの実結果を読む。

## 7. merge後に赤の場合

`main`へ直接修正しない。

1. 新しいfix branchを作る
2. 再現testまたは既存の失敗testで原因を固定する
3. 修正してtargeted testを通す
4. follow-up PRを作る
5. GitHub CI greenを確認してからmergeする

production影響や不可逆migrationがある場合は、rollback可否と影響を説明し、人間確認を待つ。

## 8. 後片付け

remote branchが削除済みで、別worktreeから参照されていないことを確認してからlocal branchを削除する。

```bash
git branch -d <branch-name>
```

仕様や運用契約が変わった場合は、PR完了前に正本docs、関連steering / skill、guardを同期する。
