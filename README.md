# Rails Portal Full Sample

Rails + Docusaurus を前提にした「社外秘ドキュメント配布ポータル」の雛形です。

## 利用者向け概要

- 案件ごとの文書公開、版管理、閲覧制御、添付配布を行う Rails ポータルです。
- Markdown 文書は Docusaurus build を公開物として扱います。
- 社外ユーザーの閲覧は `ProjectMembership` と `DocumentPermission` に基づきます。

## 開発者向け入口

- repo 固有ルールは [AGENTS.md](./AGENTS.md) と [docs/README.md](./docs/README.md) を正本とします。
- repo の位置づけ、利用者像、関連 repo との責務境界は [Product Profile.md](./Product%20Profile.md) を参照してください。
- 構造や責務分離は [docs/開発・保守ガイド.md](./docs/開発・保守ガイド.md) を参照してください。
- フロントエンドの操作方針と `tree_view` / `rails_table_preferences` / `rails_fields_kit` の役割分担は [doc/frontend_interaction_policy.md](./doc/frontend_interaction_policy.md) を参照してください。
- 関連 gem の使用箇所と upstream docs / issue の入口は [docs/関連gem連携調査runbook.md](./docs/関連gem連携調査runbook.md) を参照してください。
- 権限や公開モデルは [docs/アプリケーション仕様.md](./docs/アプリケーション仕様.md) と配下の [分割仕様](./docs/specs/基本モデルと権限.md)、検証方針は [docs/テスト方針.md](./docs/テスト方針.md) を参照してください。`internal` が admin surface を担い、`company_master_admin` は自社 `会社` / `ユーザー` 管理に限られる current contract もここを正本にします。
- ローカル編集から seed / import / portal 更新までの最小確認手順は [docs/ローカル編集からポータル更新までの最小運用案.md](./docs/ローカル編集からポータル更新までの最小運用案.md) を参照してください。
- `build-docs` workflow の manifest 生成、artifact、Rails import API 呼び出し条件を見直すときは [docs/build-docs workflow確認runbook.md](./docs/build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) を参照してください。
- ダッシュボード、文書ショートカット、確認依頼の使い分けは [docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md](./docs/%E3%83%80%E3%83%83%E3%82%B7%E3%83%A5%E3%83%9C%E3%83%BC%E3%83%89%E3%81%A8%E6%96%87%E6%9B%B8%E3%82%B7%E3%83%A7%E3%83%BC%E3%83%88%E3%82%AB%E3%83%83%E3%83%88%E3%83%BB%E7%A2%BA%E8%AA%8D%E4%BE%9D%E9%A0%BC%E3%81%AE%E4%BD%BF%E3%81%84%E5%88%86%E3%81%91.md) を参照してください。
- 案件配下の `文書一覧` と左の `文書ツリー` で検索・実用フィルタ・ZIP 出力を見直すときは [docs/文書一覧の検索・実用フィルタ・ZIP出力runbook.md](./docs/%E6%96%87%E6%9B%B8%E4%B8%80%E8%A6%A7%E3%81%AE%E6%A4%9C%E7%B4%A2%E3%83%BB%E5%AE%9F%E7%94%A8%E3%83%95%E3%82%A3%E3%83%AB%E3%82%BF%E3%83%BBZIP%E5%87%BA%E5%8A%9Brunbook.md) を参照してください。
- 版詳細画面で HTML本文、比較対象版との差分、workspace ナビゲーション、添付・元ファイルの検索 / 分類絞り込み、品質チェックの入口を見直すときは [docs/版詳細プレビュー・差分・添付確認runbook.md](./docs/%E7%89%88%E8%A9%B3%E7%B4%B0%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%83%BB%E5%B7%AE%E5%88%86%E3%83%BB%E6%B7%BB%E4%BB%98%E7%A2%BA%E8%AA%8Drunbook.md) を参照してください。
- ZIP 添付のプレビュー画面で、一覧フィルタ、個別プレビュー、個別ダウンロードの使い分けを確認するときは [docs/ZIPプレビューと個別ダウンロード確認runbook.md](./docs/ZIP%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E5%80%8B%E5%88%A5%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E7%A2%BA%E8%AA%8Drunbook.md) を参照してください。
- 管理ダッシュボードの `モデル観測` `アプリ設定診断` `文書ファイル健全性` を日常運用で見直すときは [docs/管理ダッシュボード・モデルブラウザ運用runbook.md](./docs/%E7%AE%A1%E7%90%86%E3%83%80%E3%83%83%E3%82%B7%E3%83%A5%E3%83%9C%E3%83%BC%E3%83%89%E3%83%BB%E3%83%A2%E3%83%87%E3%83%AB%E3%83%96%E3%83%A9%E3%82%A6%E3%82%B6%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- アクセス申請・同意管理・Webhook の管理画面を日常運用で見直すときは [docs/アクセス申請・同意管理・Webhook運用runbook.md](./docs/%E3%82%A2%E3%82%AF%E3%82%BB%E3%82%B9%E7%94%B3%E8%AB%8B%E3%83%BB%E5%90%8C%E6%84%8F%E7%AE%A1%E7%90%86%E3%83%BBWebhook%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- `company_master_admin` が current `main` で使える `会社` / `ユーザー` 画面、`/admin` 直行時に `会社` 画面へ redirect される current flow、internal admin へ戻す境界は [docs/company_master_admin会社・ユーザー管理runbook.md](./docs/company_master_admin%E4%BC%9A%E7%A4%BE%E3%83%BB%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC%E7%AE%A1%E7%90%86runbook.md) を参照してください。
- `案件` 作成から `Git連携` / `文書セット` の最初の 1 件を 0 件から立ち上げるときは [docs/案件・Git連携・文書セット初回セットアップrunbook.md](./docs/%E6%A1%88%E4%BB%B6%E3%83%BBGit%E9%80%A3%E6%90%BA%E3%83%BB%E6%96%87%E6%9B%B8%E3%82%BB%E3%83%83%E3%83%88%E5%88%9D%E5%9B%9E%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97runbook.md) を参照してください。
- 監査ログの絞り込み項目と最新 200 件の見方は [docs/監査ログ運用runbook.md](./docs/%E7%9B%A3%E6%9F%BB%E3%83%AD%E3%82%B0%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- 文書利用状況画面で案件単位の集計を読むときは [docs/文書利用状況運用runbook.md](./docs/%E6%96%87%E6%9B%B8%E5%88%A9%E7%94%A8%E7%8A%B6%E6%B3%81%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- 生成ファイルイベント、生成ファイル実行履歴、定期ジョブの見分け方と再試行導線は [docs/生成ファイル再試行と定期ジョブ管理runbook.md](./docs/%E7%94%9F%E6%88%90%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E5%86%8D%E8%A9%A6%E8%A1%8C%E3%81%A8%E5%AE%9A%E6%9C%9F%E3%82%B8%E3%83%A7%E3%83%96%E7%AE%A1%E7%90%86runbook.md) を参照してください。
- Git 連携設定の登録、手動同期、同期履歴の見直し順は [docs/Git連携設定と同期失敗確認runbook.md](./docs/Git%E9%80%A3%E6%90%BA%E8%A8%AD%E5%AE%9A%E3%81%A8%E5%90%8C%E6%9C%9F%E5%A4%B1%E6%95%97%E7%A2%BA%E8%AA%8Drunbook.md) を参照してください。
- ZIP インポートで dry-run を作ってから取り込み前確認を進めるときは [docs/ZIPインポートdry-run運用runbook.md](./docs/ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- internal upload API 3 系統の dry-run 作成と apply 導線を見分けるときは [docs/internal upload API dry-run・apply運用runbook.md](./docs/internal%20upload%20API%20dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- 外部フォルダ同期の provider-aware な入口、一覧の review filters、Google Drive の current support、SharePoint / OneDrive の準備導線は [docs/外部フォルダ同期dry-run・apply運用runbook.md](./docs/%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9Fdry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md) を参照してください。
- 標準 seed サンプルの種類と確認用途は [docs/標準seedサンプルと確認用途.md](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を参照してください。
- Office preview の接続前提と確認手順は [docs/Microsoft Graph接続とOffice preview.md](./docs/Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を参照してください。
- 案件ごとの `preview利用`、有効接続の整理、Drive ID、プレビュー用フォルダの見直し順は [docs/Microsoft Graph接続管理runbook.md](./docs/Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md) を参照してください。
- `API仕様` 管理画面で `docs-src` 更新後の build 待ちと HTML 確認を進めるときは [docs/API仕様ページとdocs-src更新確認runbook.md](./docs/API%E4%BB%95%E6%A7%98%E3%83%9A%E3%83%BC%E3%82%B8%E3%81%A8docs-src%E6%9B%B4%E6%96%B0%E7%A2%BA%E8%AA%8Drunbook.md) を参照してください。
- Docusaurus seed build / manual preview renderer / Kroki の runtime 前提と関連環境変数は [docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md) を参照してください。

## 外部サンプル文書

`rails db:seed` は `db/data/*.csv` に加えて、`storage/document_files/external_samples/` 配下の文書も取り込みます。

- 基本の配置規約は `storage/document_files/external_samples/<sample-set>/<site-dir>/...` です。
- `site-dir` ごとに 1 Project を作り、Markdown は 1 ファイルまたは 1 ディレクトリを 1 Document として扱います。
- `README.md` はその階層のトップページとして扱い、`site-dir` 直下の Markdown は current 版、`編集正本` や `提出済` などの配下は別 `DocumentVersion` として取り込みます。
- HTML 表示は Document 詳細から辿れても、公開側の主要 route は `Project: code`、`Document: slug`、`DocumentVersion / DocumentFile: public_id` を使います。
- 標準 showcase は seed 時に `seed-showcase/docs-portal-demo` として再生成されるため、直接編集せず [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を正本にしてください。
- `ai-usecases` は手順書系コンテンツの初期サンプルです。標準 showcase、`ai-usecases`、任意 `external_samples` の役割分担も同じく [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を参照してください。
- Docusaurus build、manual Markdown/MDX preview、Kroki、関連環境変数の runtime 前提は [docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md) にまとめています。
- PlantUML / D2 を含む Markdown を seed したい場合は Kroki が必要です。compose 切り替えや `.env` の見方は [docs/ローカルセットアップと環境変数.md](./docs/%E3%83%AD%E3%83%BC%E3%82%AB%E3%83%AB%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%E3%81%A8%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0.md) を参照してください。
- 既存のサンプル文書を持ち込む場合は対象ディレクトリをこの配下へ `cp -r` します。`bin/setup_external_sample_data_links` はベースディレクトリ作成だけを行います。

## 運用メモ

- `storage/imports/` は internal import API が読み取ってよい唯一の import ルートです。`artifact_root` と `manifest_path` はこの配下に置いてください。
- 社外ユーザーの Project 参照は `project_memberships` がある案件に限定されます。
- 社外ユーザーの添付ファイル配信は `DocumentPermission.access_level = download` がある場合だけ許可されます。
- 文書詳細の「表示」リンクは、対応する Docusaurus 生成 HTML が実在する版にだけ出ます。

## サンプルログイン情報

- admin@example.com / password123!
- staff@example.com / password123!
- client-a@example.com / password123!
- client-b@example.com / password123!