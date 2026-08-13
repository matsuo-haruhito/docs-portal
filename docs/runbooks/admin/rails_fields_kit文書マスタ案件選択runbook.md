# rails_fields_kit 文書マスタ案件選択 runbook

この runbook は、`admin/documents` の文書マスタ form で `rails_fields_kit` を確認するときの入口です。[関連 gem 連携調査 runbook](../ops/関連gem連携調査runbook.md) は 3 gem 全体と代表 smoke の正本、この文書は文書マスタの案件選択 field だけを短く確認する補助 runbook です。

## 現在の実装範囲

- `app/views/admin/documents/_form.html.slim` の `project_id` は `form.rfk_combobox` を使います。
- 案件候補は `project_search_admin_documents_path(format: :json)` から検索し、保存済み値とvalidation error後の値は `selected_project_admin_documents_path(format: :json)` で復元します。
- 候補 label は `案件コード / 案件名`、送信値はProjectのDB IDで、params名は従来どおり `document[project_id]` です。
- 検索語は前後空白を除いて最大100文字、候補は最大20件に制限します。
- `category`、`document_kind`、`visibility_policy`、`source_authority` も `form.rfk_select` で描画します。
- 文書マスタindexではformを見出し横の初期状態を閉じた `新規登録` Disclosure内に置き、validation error時だけ開きます。form fieldはDisclosure内でも通常どおり送信対象です。
- 権限、project scoping、DB schema、RTP `table_key` はこの連携では変更していません。

## 先に確認するファイル

1. `app/views/admin/documents/_form.html.slim`
2. `app/views/admin/documents/index.html.slim`
3. `app/controllers/admin/documents_controller.rb`
4. `spec/requests/admin_documents_project_select_spec.rb`
5. `spec/requests/admin_document_project_search_spec.rb`
6. `app/frontend/entrypoints/application.js`
7. `vite.config.ts`
8. `config/initializers/rails_fields_kit.rb`
9. [関連 gem 連携調査 runbook](../ops/関連gem連携調査runbook.md)

## 確認観点

- 新規作成formと編集formのどちらでも `[name="document[project_id]"]` が残っていること。
- fieldの `data-controller` がgem提供のTom Select controllerを指し、検索URL、selected URL、value / label / search field metadataが描画されること。
- edit画面では既存documentのprojectがselectedになること。
- invalid createでは、送信したprojectと入力値を保持したまま `details.admin-create-panel[open]` 内へ再描画されること。
- invalid updateでも送信したprojectがfield上は復元され、保存済みdocumentのprojectはvalidation failureで変更されないこと。
- `project_id` をremote combobox化しても、enum field、一覧filter、RTP table、案件作成、認可境界を一緒に変えないこと。

## 切り分け

- `project_id` のfield名、検索payload、selected値、validation rerenderだけが崩れる場合は `docs-portal` 側のcontroller / helper / form / request specを優先します。
- Tom Select controllerの登録、package-root import、direct entrypoint、Vite aliasが論点の場合は [関連 gem 連携調査 runbook](../ops/関連gem連携調査runbook.md) と `rails_fields_kit` upstream docsを先に確認します。
- 案件検索対象や候補上限を変える判断、他画面への横展開、upstream public API変更はこのrunbookで先回りして定義しません。
