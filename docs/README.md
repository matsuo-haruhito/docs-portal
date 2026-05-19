# docs

このディレクトリは、この repo で運用する仕様・規約・方針の置き場です。

## 最初に読む

1. [アプリケーション仕様](./アプリケーション仕様.md)
2. [テスト方針](./テスト方針.md)
3. [開発・保守ガイド](./開発・保守ガイド.md)
4. タスクに関係する補助仕様や runbook

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
- [Client file upload API flow](./client_file_upload_api.md)

## UIモック

- [Markdown編集・HTMLプレビュー・版差分ビュワー](./ui-mocks/markdown_preview_diff_viewer.html)

## 開発・運用

- [開発・保守ガイド](./開発・保守ガイド.md)
- [コーディング規約](./コーディング規約.md)
- [テスト方針](./テスト方針.md)
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
- [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md)
- [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)

## Runbook

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
   - internal user
   - admin user
   - company_master_admin user
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