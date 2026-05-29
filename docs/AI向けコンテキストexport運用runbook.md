# AI向けコンテキストexport運用runbook

この runbook は、案件詳細の `AI向けコンテキスト` 画面で、案件内文書を AI に渡すための context として確認・export するときの current behavior をまとめます。

## 1. 入口

1. 案件詳細を開く
2. actions の `AI向けコンテキスト` を開く
3. まず HTML preview で `mode`、`exported` 件数、`含まれる文書`、`除外された文書` を確認する
4. 必要に応じて `compact` / `full` を切り替える
5. `JSON` または `Markdown` で export する

route は `project_ai_context_path(project)` です。URL 上は `projects/:project_code/ai_context` 配下で、案件 access がない user は `require_project_access!` で止まります。

## 2. HTML preview で見ること

HTML preview は、download する前に export plan を読む画面です。

- `mode`: current mode。指定がない場合は `compact`
- `exported`: JSON / Markdown に含まれる文書数
- `含まれる文書`: viewer が閲覧でき、export 対象になる文書
- `除外された文書`: scope 内にはあるが viewer が閲覧できない文書
- `reason`: current code では `viewable` または `not_viewable`

preview を見た時点でも AccessLog は残ります。download 前の確認画面として扱い、`除外された文書` がある場合は、権限設定を先に見直すべきか、export 対象外として問題ないかを判断してから進めます。

## 3. compact / full の使い分け

`compact` は既定 mode です。各文書について metadata と `search_body_text` の先頭要約だけを出します。

- AI に渡す文書一覧や候補整理をしたい
- まず対象文書の数やカテゴリを確認したい
- 本文を広く渡しすぎたくない

`full` は各文書の `search_body_text` 本文を含めます。

- AI に文書本文を読ませたい
- 差分調査や要約作成の材料として本文が必要
- export 前に `含まれる文書` が意図どおりであることを確認済み

current exporter が扱う本文は `DocumentVersion#search_body_text` です。添付ファイルの binary、元ファイルそのもの、Docusaurus build artifact、コメント、監査ログは export 本文には含めません。

## 4. JSON / Markdown の使い分け

`JSON` は機械処理しやすい構造化 export です。`project`、`viewer`、`mode`、`summary`、`documents` を含みます。`compact` では文書ごとに `summary`、`full` では `body_text` が入ります。

`Markdown` は人が読みやすく、そのまま AI prompt に貼りやすい export です。案件名、code、mode、viewer、document_count の後に、文書ごとの metadata と summary または本文が並びます。

どちらの形式でも、export される `documents` は viewer が閲覧できる文書だけです。HTML preview で `除外された文書` に出た文書は、JSON / Markdown の文書本文には入りません。

## 5. 権限と監査ログ

AI context export は、案件 access と文書 visibility の両方を前提にします。

- 案件 access は `Project.accessible_to(current_user)` と `require_project_access!` の範囲で扱う
- 文書ごとの export 可否は `visible_in_portal_for?(viewer)` で判定する
- JSON / Markdown には viewer が閲覧できる文書だけを入れる
- HTML preview は `含まれる文書` と `除外された文書` を分けて表示する

AccessLog は HTML preview と JSON / Markdown download の両方で作成されます。

- HTML preview: `action_type: view`
- JSON / Markdown: `action_type: download`
- `target_type: ai_context`
- `target_name: mode=<mode>`

ログ作成に失敗した場合は controller が error log を出して処理を継続します。監査上は `監査ログ` 画面で `target_type` や action を見て、preview と download の両方が残る前提で確認します。

## 6. scope 指定の current support

controller は `document_ids` param を受け取り、指定された案件内文書だけを scope として扱えます。ただし current UI には文書選択用の selector はありません。

- 通常操作では、案件内文書全体を対象に preview / export する
- 手動で `document_ids[]` を渡した場合、指定 scope の中で `含まれる文書` / `除外された文書` が分かれる
- scope に含めた文書でも、viewer が閲覧できなければ JSON / Markdown には入らない

この runbook では、scope selection UI、保存済み export 設定、外部 AI サービス連携は current support として扱いません。

## 7. この画面でやること / やらないこと

### やること

- 案件単位の AI context preview
- compact / full の切り替え
- JSON / Markdown export
- export 対象と除外文書の確認
- access log を残す前提での preview / download

### やらないこと

- 文書権限の変更
- export schema の変更
- UI 上での細かな scope selection
- 外部 AI サービスへの自動送信
- 添付 binary や build artifact の export
- AI prompt の保存や履歴管理

## 8. current support の境界

- この runbook は current `main` の `ProjectAiContextsController`、`AiContextHashExporter`、`AiContextMarkdownExporter`、`AiContextExportPlan` を正本にします
- JSON / Markdown は viewer が閲覧できる文書だけを export する説明に閉じます
- HTML preview の `除外された文書` は、download 対象外を確認するための current 表示として扱います
- scope selection UI や外部 AI 連携は未実装として扱い、実装済みとは書きません
- export 対象の拡張や schema 変更が必要な場合は、別 issue で code / spec と一緒に判断します
