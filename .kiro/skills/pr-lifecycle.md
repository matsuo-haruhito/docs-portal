---
name: "PRライフサイクル"
description: "PR作成 → CI確認 → マージ → テスト確認 → ブランチ削除までを一貫して進める"
---
# PRライフサイクル

PR作成からマージ、後片付けまでを一貫して進める。
issue解決スキルから自動的に連鎖して呼ばれるが、単独でも使える。

## 制約

- CI結果待ちのタイムアウト: **3分**。3分以内に結果が出ない場合は中断してユーザーに報告する。

## ワークフロー

### 1. PR作成

- 現在のブランチの変更をpush:
  ```
  git push -u origin HEAD
  ```
- PRを作成:
  ```
  gh pr create --base main --fill
  ```
- issue解決から呼ばれた場合、PR本文に `Closes #<number>` が含まれていることを確認する

### 2. PR時CI（関連箇所テスト）

変更に関連するテストのみ実行する（3分タイムアウト）。

- 変更されたファイルから影響範囲を特定:
  ```
  gh pr diff --name-only
  ```
- 影響するspecファイルを推定し、実行:
  ```
  bundle exec rspec <関連specファイル>
  ```
  Docker環境の場合:
  ```
  docker compose run --rm app bundle exec rspec <関連specファイル>
  ```
- 推定ルール:
  - `app/models/xxx.rb` → `spec/models/xxx_spec.rb`
  - `app/controllers/xxx_controller.rb` → `spec/requests/xxx_spec.rb`
  - `app/controllers/admin/xxx_controller.rb` → `spec/requests/admin_xxx_spec.rb`
  - `app/services/xxx.rb` → `spec/services/xxx_spec.rb`
  - `app/importers/xxx.rb` → `spec/importers/xxx_spec.rb`
  - `app/views/xxx/` → そのコントローラーのrequest spec
  - マイグレーション → seed spec + schema系spec
  - spec自体の変更 → その spec を実行

### 3. CI結果確認と修正

- テストが赤の場合:
  - 失敗内容を分析し修正する
  - 修正を同じブランチにコミット・push
  - 再度テスト実行して確認
  - 緑になるまで繰り返す（ただし3分タイムアウトは各テスト実行に適用）
- テストが緑の場合:
  - マージへ進む

### 4. マージ

```
gh pr merge --squash --delete-branch
```

- `--squash` でコミットをまとめる
- `--delete-branch` でリモートブランチを自動削除

### 5. マージ後確認

- main に切り替え:
  ```
  git checkout main && git pull
  ```
- フルテスト実行:
  ```
  bin/all_test
  ```
- 結果確認:
  - `tmp/all_test/summary.txt` を確認
  - 全ステップが緑ならOK

### 6. マージ後に赤の場合

- main 上で直接修正コミットする（1ファイル以内の小修正の場合）
- または新しいブランチを切って修正PR → 再度このスキルを回す（大きな修正の場合）

### 7. 後片付け

- ローカルブランチを削除:
  ```
  git branch -d <branch-name>
  ```
- docs/ の更新が必要であれば反映する

## 使い方

issue解決からの自動連鎖:
```
#42 のissue解決で進めて
```
→ 実装完了後にPRライフサイクルが自動実行される

単独で使う場合:
```
今のブランチでPRライフサイクル回して
```

```
この変更のPR作ってマージまでやって
```
