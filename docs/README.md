# docs

このディレクトリは、この repo で運用する仕様・規約・方針の置き場です。

## 最初に読む

1. [Product Profile](../Product%20Profile.md)
2. [アプリケーション仕様](./アプリケーション仕様.md)
3. [テスト方針](./テスト方針.md)
4. [開発・保守ガイド](./開発・保守ガイド.md)
5. タスクに関係する補助仕様や runbook

UI / JavaScript / Vite / Stimulus / 関連 gem を触る場合は、[フロントエンド操作の方針](../doc/frontend_interaction_policy.md) も先に確認してください。

## 仕様

- [アプリケーション仕様](./アプリケーション仕様.md)
- [基本モデルと権限](./specs/基本モデルと権限.md)
- [閲覧画面とUI](./specs/閲覧画面とUI.md)
- [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)
- [importと変更系dry-run](./specs/importと変更系dry-run.md)
- [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md)
- [Git連携インポート](./Git連携インポート.md)
- [Google Drive外部フォルダ同期](./Google%20Drive外部フォルダ同期.md)
- [利用規約・秘密保持の同意管理](./利用規約・秘密保持の同意管理.md)
- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md)
- [Internal upload API naming](./internal_upload_api_naming.md)
- [Client file upload API flow](./client_file_upload_api.md)
- [Local folder sync client design](./local_folder_sync_client.md)

## UIモック

- [Markdown編集・HTMLプレビュー・版差分ビュワー](./ui-mocks/markdown_preview_diff_viewer.html)

## 開発・運用

- [開発・保守ガイド](./開発・保守ガイド.md)
- [フロントエンド操作の方針](../doc/frontend_interaction_policy.md)
- [コーディング規約](./コーディング規約.md)
- [テスト方針](./テスト方針.md)
- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md): `.env.example` を基準にした最短起動手順と optional service の切り替え
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md): ローカルで文書を編集して seed / import / portal 更新まで確認する最小フロー
- [標準 seed サンプルと確認用途](./標準seedサンプルと確認用途.md): repo 標準 showcase、`ai-usecases`、任意 `external_samples` の違いと確認観点
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md): preview 接続、同期元設定、SharePoint / OneDrive の metadata 保存 first slice、`.env` の役割分担
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
- [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md)
- [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md): seed build / manual preview renderer / Kroki / 関連 env の runtime 前提

## Runbook

- [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md): dashboard 起点の個人導線と internal user 向け確認依頼の役割差
- [利用者向けアクセス申請runbook](./利用者向けアクセス申請runbook.md): dashboard の `保留中の申請` から入る一覧、`対象` `要求権限` `状態` `理由` `承認者`、pending の `取消` の見方
- [外部送付履歴運用runbook](./外部送付履歴運用runbook.md): dashboard の `社内向け導線` から入る `送付履歴` 一覧、detail、`メーラーを開く` / `送付済みにする` / `送付失敗として記録` の見分け方
- [文書一覧の検索・実用フィルタ・ZIP出力 runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md): 案件配下の検索条件、左の文書ツリー絞り込み、実用フィルタ、current-page 選択と検索結果全体選択を含む ZIP 出力の見分け方
- [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md): HTML本文、比較対象版、workspace ナビゲーション、添付・元ファイルの検索 / 分類絞り込み、Markdown table annotation first slice と未対応範囲、品質チェックの見分け方
- [ZIPプレビューと個別ダウンロード確認 runbook](./ZIP%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E5%80%8B%E5%88%A5%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E7%A2%BA%E8%AA%8Drunbook.md): ZIP内サマリー、ディレクトリサマリー、フィルタ、個別プレビュー、個別ダウンロードの見分け方
- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md): `モデル観測` `アプリ設定診断` `文書ファイル健全性` の使い分けと戻り先
- [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md): `アクセス申請` `同意文面` `案件同意設定` `Webhook` の日常確認ポイントと戻り先
- [利用者向け同意画面・同意履歴runbook](./利用者向け同意画面・同意履歴runbook.md): `同意済み文面・注意事項` と `利用上の注意事項への同意` の見分け方、`確認して同意する` / `同意せず戻る` の current flow
- [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md): `company_master_admin` が current `main` で使える `会社` / `ユーザー` 画面、`/admin` 直行時に `会社` 画面へ redirect される current flow、internal admin へ戻す境界
- [文書マスタ運用runbook](./文書マスタ運用runbook.md): `admin/documents` の検索・状態確認、保管期限 / 廃棄候補、公開側文書への戻り方、`編集` / `アーカイブ` / `復元` / `削除` の見分け方
- [案件・Git連携・文書セット初回セットアップrunbook](./案件・Git連携・文書セット初回セットアップrunbook.md): `案件` 作成、`Git連携` の最小構成、初回取り込み後の `文書セット` 作成順
- [文書セット運用runbook](./文書セット運用runbook.md): `文書セット` 一覧の列、`固定版` と `最新版を使う` の使い分け、文書 0 件案件の empty state の戻り先
- [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md): `案件所属` の role 管理と、`文書権限` の 0 件開始時 empty state、件数確認、個別付与確認の見分け方
- [監査ログ運用runbook](./監査ログ運用runbook.md): `監査ログ` の絞り込み項目、表示設定、最新 200 件の中でどの列を残して読むか
- [文書利用状況運用runbook](./文書利用状況運用runbook.md): `文書利用状況` の案件単位集計、利用あり/なし、関連画面への戻り先
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md): `rails_fields_kit` / `rails_table_preferences` / `tree_view` の upstream 入口と、`admin/document_sets` を代表例にした host app cookbook
- [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md): `定期ジョブ` / `生成ファイルイベント` / `生成ファイル実行履歴` の見分け方と再試行導線
- [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md): `test` / `seed-smoke` / `build-docs` の見分け方、manifest 生成、artifact、import API の確認順
- [Git連携設定と同期失敗確認runbook](./Git連携設定と同期失敗確認runbook.md): `Git連携` / `Git同期履歴` で見る項目と手動同期の戻り先
- [ZIPインポートdry-run運用runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md): `ZIPインポート` の入力項目、status、TreeView プレビュー、取り込み前の見直し順
- [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md): `artifact_imports` / `zip_uploads` / `file_uploads` の dry-run 作成と apply の見分け方
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md): `preview利用` 列、重複有効接続の整理、Drive ID、プレビュー用フォルダの見直し順
- [API仕様ページとdocs-src更新確認runbook](./API%E4%BB%95%E6%A7%98%E3%83%9A%E3%83%BC%E3%82%B8%E3%81%A8docs-src%E6%9B%B4%E6%96%B0%E7%A2%BA%E8%AA%8Drunbook.md): `API仕様` 管理画面で build 待ちと主要ページの HTML 確認を進めるときの入口
- [外部フォルダ同期dry-run・apply運用runbook](./外部フォルダ同期dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md): provider-aware な入口、`最新安全判定` / `競合・重複警告`、Google Drive の current support、SharePoint / OneDrive の metadata 保存 first slice と未対応の同期本体
- [リリース・デプロイ・rollback手順](./リリース・デプロイ・rollback手順.md)
- [バックアップ・リストア手順](./バックアップ・リストア手順.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
- [監視・アラート設計](./監視・アラート設計.md)

## 未確定事項

- [ToDo](./ToDo.md)

## 仕様概要

1. 識別子
   - DB id
   - public_id
   - code / slug
   - URL に出す ID

2. アクセス制御
   - internal user (`User#admin?` / admin surface)
   - company_master_admin user (自社 `会社` / `ユーザー` 管理のみ)
   - external user
   - project membership
   - document permission
   - view/download

3. ドキュメント公開モデル
   - Document
   - DocumentVersion
   - DocumentFile
   - draft / published / archived
   - latest_version
   - バージョン管理あり / なし

4. Docusaurus 表示
   - build 成果物
   - site_build_path
   - rendered_site_available?
   - assets の扱い

5. 添付ファイル
   - Markdown は生ファイル表示
   - download 権限
   - content type / charset

6. Import
   - publish.json
   - version immutability
   - storage_key
   - build artifact
   - Git連携 import source / run
   - ZIP import dry-run / 実行
   - 外部フォルダ同期 source / run / item
   - file_uploads / zip_uploads / artifact_imports の internal API

7. AccessLog
   - 記録対象
   - 記録しない対象
   - last_login_at は users 側で管理

8. 外部連携
   - Webhook endpoint
   - 通知対象イベント
   - 署名付き JSON POST
   - 送信履歴
   - Google Drive外部フォルダ同期

9. 将来対応
   - 現時点の仕様に含めないものは [ToDo](./ToDo.md) に記載する
