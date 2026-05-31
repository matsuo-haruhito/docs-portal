# rails_fields_kit 文書マスタ案件選択 runbook

この runbook は、`admin/documents` の文書マスタ form で `rails_fields_kit` を確認するときの入口です。`docs/関連gem連携調査runbook.md` は 3 gem 全体と代表 smoke の正本、この文書は PR #1357 merge 後に current `main` へ入った文書マスタの案件選択 field だけを短く確認する補助 runbook です。

## 現在の実装範囲

- `app/views/admin/documents/_form.html.slim` の `project_id` は `form.rfk_select` を使います。
- `collection: @projects`、`collection_value_method: :id`、`collection_label_method: :name` を明示し、送信される params は従来どおり `document[project_id]` です。
- `category`、`document_kind`、`visibility_policy` は引き続き通常の `form.select` です。
- remote search endpoint、文書マスタ index、権限、project scoping、DB schema はこの slice では変更していません。

## 先に確認するファイル

1. `app/views/admin/documents/_form.html.slim`
2. `spec/requests/admin_documents_project_select_spec.rb`
3. `app/frontend/entrypoints/application.js`
4. `vite.config.ts`
5. `config/initializers/rails_fields_kit.rb`
6. `docs/関連gem連携調査runbook.md`

## 確認観点

- 新規作成 form と編集 form のどちらでも `select[name="document[project_id]"]` が残っていること。
- edit 画面では既存 document の project が selected になること。
- invalid create / invalid update の rerender 後も、送信した project が selected のまま戻ること。
- `project_id` 以外の enum select を同時に `rfk_select` 化したように読める docs や spec になっていないこと。
- `rails_fields_kit` の controller registration や Vite alias を変える必要が出た場合は、文書マスタ固有の問題か upstream docs / public API の問題かを切り分けること。

## 切り分け

- `project_id` の field 名、選択済み値、validation rerender だけが崩れる場合は `docs-portal` 側の form / request spec を優先します。
- `TomSelectController` の登録、package root import、direct entrypoint、Vite alias が論点の場合は `docs/関連gem連携調査runbook.md` と `rails_fields_kit` upstream docs を先に確認します。
- remote search、新しい文書マスタ field の `rfk_select` 化、他画面への横展開はこの runbook の current support ではなく、別 issue / PR で扱います。

## 変更履歴メモ

- PR #1357: 文書マスタ form の案件選択を `rails_fields_kit` helper に置き換え、initial load / edit / invalid rerender の request spec を追加しました。
