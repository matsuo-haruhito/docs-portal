# 閲覧画面とUI

この文書は、利用者画面、管理画面、viewer 導線の正本です。

## 画面

- ブランド名クリックで TOP に戻る
- 管理画面は `admin` または `company_master_admin` がアクセス可能とする
- `admin` は全管理機能を利用できる
- `admin` は Project 編集画面から標準文書テンプレートの preview と適用を実行できる
- `admin` は案件単位の文書利用状況レポートを参照できる
- `admin` は管理メニューの「API仕様」から、ドキュメント更新用 internal import API の仕様を参照できる
- API仕様ページは `docs-src/api-specification.md` を Docusaurus build した HTML を same-origin iframe で表示する
- API仕様ページは source Markdown が生成済み HTML より新しい場合に build job を enqueue し、生成HTMLの鮮度確認は `BuildFreshnessGuard` で共通化する
- `company_master_admin` は自社の会社マスタ・自社ユーザー管理のみ利用できる
- 文書詳細では `tree_view` gem を使って「案件 > 文書」の左ペインツリーを表示する
- 文書詳細と版詳細の「添付・元ファイル」は、保持している相対 path を使って `tree_view` でフォルダ階層表示する
- Project 配下で文書カタログ一覧・詳細を表示できる
- 管理画面には、主要 model の件数・最近の record・既存 CRUD への入口を横断表示する `model browser` を持つ
- 403 / 404 / 400 は利用者向けエラー画面で表示し、平文レスポンスにはしない

## 利用者ダッシュボード

- ログイン後に `GET /dashboard` で利用者向けダッシュボードを表示できる
- dashboard には、自分が閲覧可能な案件、お気に入り、後で読む、最近見た文書、最近更新された文書を表示する
- dashboard には、案件数・文書数・保存ショートカット数・保留中申請数などの workspace summary を表示する
- 権限外文書は bookmark や access log に存在しても表示しない

## Docusaurus viewer

- `GET /projects/:project_code/site/*site_path` および `GET /document_versions/:public_id/site/*site_path` の HTML 応答は、初期表示では viewer shell を返す
- viewer shell は Rails 側の header / breadcrumb / action を持ち、本文部分は same-origin iframe で読み込む
- iframe 側の本文は `embedded=1` 付き同 route を使って取得する
- iframe 側では Docusaurus navbar / footer / toc / sidebar を除去し、本文を中央寄せで表示する
- iframe 側で rewrite される内部 link / asset URL も `embedded=1` を維持する

## Office file preview

- `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` は Office preview 対象とする
- Office preview は管理画面の `Microsoft Graph` 接続マスタで案件ごとに設定する
- 接続マスタには tenant ID、client ID、client secret、drive ID、プレビュー用フォルダを保存する
- client secret は暗号化カラムに保存する
- 文書詳細の embedded file viewer で Office file を表示する場合、Rails は Microsoft Graph の client credentials flow で access token を取得する
- Rails は対象ファイルを設定済み Drive のプレビュー用フォルダへ一時アップロードし、その driveItem に対して `/preview` を呼び出す
- 250MBを超えるOffice fileはGraphへアップロードせず、iframe内に「プレビュー不可・ダウンロードのみ」の案内を表示する
- iframe には Rails の `document_files/:public_id?embedded=1` を読み込ませ、同 route から Graph の preview URL へ redirect する
- Graph preview URL は一時 URL として扱い、DB に永続化しない
- Office preview への遷移もファイル閲覧として access log を記録する
- Graph preview を作成できない場合は 502 とし、通常のダウンロード導線は残す

## 危険操作の安全装置

- 危険操作に対して confirm と影響表示を優先する
- admin 画面の delete 操作は `turbo_confirm` 付きで実行する
- 変更前確認導線は、適用処理から分離した dry-run / preview として扱う

## DocumentReviewComment / Q&A

- `DocumentReviewComment` は internal review と公開 Q&A の共通 comment thread として使う
- コメント対象は `Document` と任意の `DocumentVersion` とする
- `internal_only = true` は社内レビュー、`false` は公開 Q&A thread として扱う
- root comment が `comment_type = question` かつ `internal_only = false` のものを Q&A thread として扱う
- external / company_master_admin / internal は、閲覧可能な文書または版の detail 画面から Q&A を投稿できる
- admin はレビューコメントの解決・却下を行える

## 文書カタログ

- `DocumentCatalog` は Project 配下の curated な文書一覧である
- route は `projects/:project_code/document_catalogs/:public_id` を使う
- 一覧では viewer が参照可能な catalog だけ表示する
- 詳細では viewer が参照可能な item だけ表示する

## 文書セット

- `DocumentSet` は Project 配下の用途別 document grouping である
- route は `projects/:project_code/document_sets/:public_id` を使う
- `admin` は管理画面から `DocumentSet` を作成・編集・削除できる
- fixed version を指定しない item は、その `Document` の `latest_version` を使う

## AI向けコンテキスト生成

- Project 単位で AI 向けコンテキスト出力を取得できる
- viewer が参照可能な Document だけを対象にする
- HTML に加えて hash / markdown 形式でも同じ対象を出力できる

## 外部送付履歴

- 文書または文書セット単位で、外部送付の履歴を `DocumentDeliveryLog` として記録する
- 利用者は自分が作成した履歴を参照できる
- admin は全履歴を参照し、状態変更や確認を行える
