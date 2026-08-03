# 仕様

機能仕様、API仕様、データモデル設計、境界メモを集めたディレクトリです。

## 主要仕様

- [基本モデルと権限](./基本モデルと権限.md) — 基本モデル・識別子・権限制御・申請系フローの正本
- [文書ライフサイクルと公開](./文書ライフサイクルと公開.md) — Document / DocumentVersion / DocumentFile の状態・公開・表示ルール
- [閲覧画面とUI](./閲覧画面とUI.md) — 利用者画面・管理画面・viewer 導線の正本
- [importと変更系dry-run](./importと変更系dry-run.md) — import / dry-run / 変更前確認系の正本
- [検索仕様](./search.md) — 文書内検索・添付ファイル検索・portal 横断検索

## API・連携仕様

- [Git連携インポート](./Git連携インポート.md) — Git リポジトリ連携インポートの初期実装範囲
- [Google Drive外部フォルダ同期](./Google%20Drive外部フォルダ同期.md) — Google Drive 外部フォルダ同期の設計
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph接続とOffice%20preview.md) — Office ファイル inline preview の接続前提と確認観点
- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md) — Webhook 配信と外部 API 連携の設計方針
- [利用規約・秘密保持の同意管理](./利用規約・秘密保持の同意管理.md) — 同意管理の初期実装範囲
- [internal_upload_api_naming](./internal_upload_api_naming.md) — 内部 API 名の設計経緯と位置づけ
- [client_file_upload_api](./client_file_upload_api.md) — クライアントファイルアップロード API フロー
- [local_folder_sync_client](./local_folder_sync_client.md) — NAS / ローカルフォルダ同期クライアント設計
- [preview接続と外部フォルダ同期の設定責務](./preview接続と外部フォルダ同期の設定責務.md) — 外部ストレージ連携の管理画面・env・scope 整理
- [external-folder-sync-webhook-ignored-events](./external-folder-sync-webhook-ignored-events.md) — 同期 webhook の ignored event 読み分け

## ファイル配信・ビルド・公開

- [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md) — publish.json の自動生成と Rails ポータルへの受け渡し
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md) — ファイル配信と storage 周辺の現行方針
- [docusaurus-build-manifest](./docusaurus-build-manifest.md) — Docusaurus build manifest の JSON metadata 仕様
- [path-history-redirect](./path-history-redirect.md) — slug / path 変更時の旧 URL → 現在 URL リダイレクト
- [archive-preview](./archive-preview.md) — ZIP / archive preview の責務と拡張方針
- [preview-target-metadata](./preview-target-metadata.md) — preview_targets metadata による表示優先度制御
- [生成ファイルイベント](./生成ファイルイベント.md) — GeneratedFileEvent による変更通知と後続ジョブ起動

## 画面・ダッシュボード

- [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md) — dashboard 日常導線の役割差

## インフラ・監視

- [本番運用・インフラ前提](./本番運用・インフラ前提.md) — 本番運用前提の整理
- [監視・アラート設計](./監視・アラート設計.md) — 監視・アラート設計の現行方針
- [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md) — import / build / mail / webhook の自動リトライ判断材料

## 境界メモ

- [CSV条件metadata_JSON運用メモ](./CSV条件metadata_JSON運用メモ.md) — CSV 条件 metadata JSON の読み方補助
- [Git連携run履歴保存境界メモ](./Git連携run履歴保存境界メモ.md) — Git 連携 run の job 化・履歴保存前の境界確認
- [ZIPインポートdry-run履歴保存境界メモ](./ZIPインポートdry-run履歴保存境界メモ.md) — ZIP import dry-run の job 化・履歴保存前の境界確認
- [build-docs-import-job化境界メモ](./build-docs-import-job化境界メモ.md) — import / build job 化の代表対象と履歴保存境界
- [build-docs-job化置き換え境界メモ](./build-docs-job化置き換え境界メモ.md) — build-docs job を Rails app 側 job に置き換える検討の棚卸し
- [search-index-rebuild履歴境界メモ](./search-index-rebuild履歴境界メモ.md) — search index rebuild 履歴の検討前提
- [site-build実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md) — 生成ファイル実行履歴を拡張する前の保存境界確認
- [正式レビュー承認workflow境界メモ](./正式レビュー承認workflow境界メモ.md) — 正式レビュー・承認 workflow 設計前の棚卸し
- [生成ファイル実行履歴preview境界メモ](./生成ファイル実行履歴preview境界メモ.md) — 実行履歴 index / detail の診断ブロック読み方補助
