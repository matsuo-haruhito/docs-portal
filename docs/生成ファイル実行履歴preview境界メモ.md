# 生成ファイル実行履歴 preview 境界メモ

このメモは、`生成ファイル実行履歴` index の検索欄と detail の下部に出る診断ブロックを読むときの補助です。基本の切り分け順、filter、retry の操作境界は [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md) を正本にします。

## 対象画面

- `admin/generated_file_runs`
- `admin/generated_file_runs/:id`
- `一覧の q 検索`
- `入力パス`
- `変更ファイル`
- `生成パス`
- `メタデータ`
- `エラー`

## 読み方

一覧の q 検索は、実行ID、入力パス、変更ファイル、生成パス、短いエラー断片、metadata に残る event public ID などのジョブ診断用の短い断片で候補を絞る入口です。検索対象に metadata text が含まれていても、一覧で raw metadata / raw payload / token-like value / private path を読むための画面ではありません。

詳細画面の診断ブロックは、生成ジョブを調査するための preview です。保存値やログの完全な raw dump ではありません。

- `入力パス` / `変更ファイル` / `生成パス` は、ジョブ診断用の配列表示として読みます。生成入力、差分、出力先を再確認する手がかりであり、検索条件や retry 対象を直接変更するものではありません。
- `メタデータ` は `generated_file_run_metadata_preview` を通した診断用 preview です。`token`、`secret`、`private path` などの secret-like value は表示前に伏せられます。
- `エラー` は `generated_file_run_diagnostic_preview` を通した診断用 preview です。長い本文は省略され、token / secret / private path は伏せられます。
- 長い metadata JSON、raw payload、error log 全文、token-like value、private path をそのまま検索欄へ貼るのではなく、`gfr...` の一部、入力パスや生成パスの特徴語、短い error 断片、metadata に残る event public ID など 100 文字以内の手掛かりで探します。

## current support ではないこと

この画面上の preview cue は、次を意味しません。

- raw log viewer の追加
- credential / private path の表示
- metadata schema の変更
- mask / truncate 対象の運用判断
- retry 回数 policy や承認 workflow の追加
- 生成ジョブの状態遷移や enqueue 条件の変更

retry 判断は引き続き、実行履歴一覧の filter、detail の retry 親子関係、`現在の条件で再実行対象` の件数、確認ダイアログを合わせて確認します。

## 根拠

- PR #3618: `app/views/admin/generated_file_runs/show.html.erb` に診断ブロックごとの preview cue を追加
- `app/helpers/admin/generated_file_runs_helper.rb`: metadata / diagnostic preview の mask と truncate 境界
