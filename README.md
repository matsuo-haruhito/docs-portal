# docs-portal

`docs-portal` は、案件ごとの社外秘ドキュメント配布を Rails + Docusaurus で運用するポータルアプリです。文書公開、版管理、閲覧制御、添付配布、import / preview / build / 外部連携の運用導線をこの repo で扱います。

## 利用者向け概要

- 案件ごとの文書公開、版管理、閲覧制御、添付配布を行う Rails ポータルです。
- Markdown 文書は Docusaurus build を公開物として扱います。
- 社外ユーザーの閲覧は `ProjectMembership` と `DocumentPermission` に基づきます。

## 開発者向け入口

まず repo 固有ルールは [AGENTS.md](./AGENTS.md)、docs 全体の索引は [docs/README.md](./docs/README.md)、repo の位置づけと関連 repo 境界は [Product Profile.md](./Product%20Profile.md) を正本にします。タスク種別ごとの最初の参照先は次の通りです。

role 別に current support の入口だけを先に選びたい場合は、次の表から既存 runbook へ進みます。権限 model や導線の正本はリンク先と current code を優先してください。

| role | 最初に見る入口 | 補足 |
| --- | --- | --- |
| external user | [ダッシュボードと文書ショートカット・確認依頼の使い分け](./docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md)、[利用者向けアクセス申請runbook](./docs/利用者向けアクセス申請runbook.md)、[利用者向け同意画面・同意履歴runbook](./docs/利用者向け同意画面・同意履歴runbook.md) | `/dashboard` 起点で閲覧可能文書、アクセス申請、同意画面を確認する |
| internal user | [ダッシュボードと文書ショートカット・確認依頼の使い分け](./docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md)、[利用者向け確認依頼runbook](./docs/利用者向け確認依頼runbook.md)、[外部送付履歴運用runbook](./docs/外部送付履歴運用runbook.md) | dashboard の社内向け導線と確認依頼、送付履歴の読み分けを確認する |
| company_master_admin | [company_master_admin会社・ユーザー管理runbook](./docs/company_master_admin会社・ユーザー管理runbook.md)、[管理画面 nav 領域見出し運用メモ](./docs/管理画面nav領域見出し運用メモ.md) | `会社` / `ユーザー` 管理に閉じる role 境界を確認する |
| internal admin | [管理ダッシュボード・モデルブラウザ運用runbook](./docs/管理ダッシュボード・モデルブラウザ運用runbook.md)、[アクセス申請・同意管理・Webhook運用runbook](./docs/アクセス申請・同意管理・Webhook運用runbook.md)、[案件・Git連携・文書セット初回セットアップrunbook](./docs/案件・Git連携・文書セット初回セットアップrunbook.md) | `/admin` 起点で管理 dashboard、申請 / 同意 / Webhook、案件初期設定を確認する |

- 基本仕様・権限: [docs/アプリケーション仕様.md](./docs/アプリケーション仕様.md)、[docs/specs/基本モデルと権限.md](./docs/specs/基本モデルと権限.md)、[docs/テスト方針.md](./docs/テスト方針.md)
- 開発・保守: [docs/開発・保守ガイド.md](./docs/開発・保守ガイド.md)、[docs/ローカルセットアップと環境変数.md](./docs/ローカルセットアップと環境変数.md)、[docs/ローカル編集からポータル更新までの最小運用案.md](./docs/ローカル編集からポータル更新までの最小運用案.md)
- フロントエンド・関連 gem: 基本方針は [doc/frontend_interaction_policy.md](./doc/frontend_interaction_policy.md)、実画面への gem 展開候補は [ROADMAP.md](./ROADMAP.md)、host app 採用と release train の確認順は [docs/関連gem連携調査runbook.md](./docs/関連gem連携調査runbook.md)、3 gem の representative smoke / upstream evidence / rollback 観点の 1 枚 map は [docs/internal-ui-gem-adoption-evidence-map.md](./docs/internal-ui-gem-adoption-evidence-map.md)、責務境界は [docs/internal-ui-gem責務境界matrix.md](./docs/internal-ui-gem責務境界matrix.md)、JS resolver / package-root import 境界は [docs/internal-ui-gem-js-resolver-matrix.md](./docs/internal-ui-gem-js-resolver-matrix.md)、上流 packaging gate と downstream smoke の境界は [docs/internal-ui-gem-packaging-gates.md](./docs/internal-ui-gem-packaging-gates.md)、static artifact 変更時の visual evidence は [docs/internal-ui-gem-visual-evidence-runbook.md](./docs/internal-ui-gem-visual-evidence-runbook.md)、代表画面別の evidence 探索入口は [docs/internal-ui-gem-visual-evidence-gallery.md](./docs/internal-ui-gem-visual-evidence-gallery.md) を見る。`#607` は screen-by-screen adoption、`#858` child issue は pinned ref / smoke / rollback note の更新管理、`#1333` のような quality issue は実装済み画面の representative smoke 固定として読み分ける
- 日常 UI / viewer: [docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md](./docs/%E3%83%80%E3%83%83%E3%82%B7%E3%83%A5%E3%83%9C%E3%83%BC%E3%83%89%E3%81%A8%E6%96%87%E6%9B%B8%E3%82%B7%E3%83%A7%E3%83%BC%E3%83%88%E3%82%AB%E3%83%83%E3%83%88%E3%83%BB%E7%A2%BA%E8%AA%8D%E4%BE%9D%E9%A0%BC%E3%81%AE%E4%BD%BF%E3%81%84%E5%88%86%E3%81%91.md)、[docs/利用者向け確認依頼runbook.md](./docs/利用者向け確認依頼runbook.md)、[docs/外部送付履歴運用runbook.md](./docs/外部送付履歴運用runbook.md)、[docs/文書ショートカット運用runbook.md](./docs/%E6%96%87%E6%9B%B8%E3%82%B7%E3%83%A7%E3%83%BC%E3%83%88%E3%82%AB%E3%83%83%E3%83%88%E9%81%8B%E7%94%A8runbook.md)、[docs/文書一覧の検索・実用フィルタ・ZIP出力runbook.md](./docs/%E6%96%87%E6%9B%B8%E4%B8%80%E8%A6%A7%E3%81%AE%E6%A4%9C%E7%B4%A2%E3%83%BB%E5%AE%9F%E7%94%A8%E3%83%95%E3%82%A3%E3%83%AB%E3%82%BF%E3%83%BBZIP%E5%87%BA%E5%8A%9Brunbook.md)、[docs/文書カタログ閲覧runbook.md](./docs/%E6%96%87%E6%9B%B8%E3%82%AB%E3%82%BF%E3%83%AD%E3%82%B0%E9%96%B2%E8%A6%A7runbook.md)、[docs/版詳細プレビュー・差分・添付確認runbook.md](./docs/%E7%89%88%E8%A9%B3%E7%B4%B0%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%83%BB%E5%B7%AE%E5%88%86%E3%83%BB%E6%B7%BB%E4%BB%98%E7%A2%BA%E8%AA%8Drunbook.md)、AI context preview / JSON / Markdown export は [docs/AI向けコンテキストexport運用runbook.md](./docs/AI向けコンテキストexport運用runbook.md) を見る
- admin 運用: [docs/company_master_admin会社・ユーザー管理runbook.md](./docs/company_master_admin会社・ユーザー管理runbook.md)、[docs/アクセス申請・同意管理・Webhook運用runbook.md](./docs/アクセス申請・同意管理・Webhook運用runbook.md)、[docs/文書マスタ運用runbook.md](./docs/%E6%96%87%E6%9B%B8%E3%83%9E%E3%82%B9%E3%82%BF%E9%81%8B%E7%94%A8runbook.md)、[docs/文書一括編集dry-run運用runbook.md](./docs/%E6%96%87%E6%9B%B8%E4%B8%80%E6%8B%AC%E7%B7%A8%E9%9B%86dry-run%E9%81%8B%E7%94%A8runbook.md)、[docs/管理ダッシュボード・モデルブラウザ運用runbook.md](./docs/%E7%AE%A1%E7%90%86%E3%83%80%E3%83%83%E3%82%B7%E3%83%A5%E3%83%9C%E3%83%BC%E3%83%89%E3%83%BB%E3%83%A2%E3%83%87%E3%83%AB%E3%83%96%E3%83%A9%E3%82%A6%E3%82%B6%E9%81%8B%E7%94%A8runbook.md)、[docs/案件・Git連携・文書セット初回セットアップrunbook.md](./docs/%E6%A1%88%E4%BB%B6%E3%83%BBGit%E9%80%A3%E6%90%BA%E3%83%BB%E6%96%87%E6%9B%B8%E3%82%BB%E3%83%83%E3%83%88%E5%88%9D%E5%9B%9E%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97runbook.md)
- import / build / sync: [docs/build-docs workflow確認runbook.md](./docs/build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md)、[docs/ZIPインポートdry-run運用runbook.md](./docs/ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md)、[docs/internal upload API dry-run・apply運用runbook.md](./docs/internal%20upload%20API%20dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md)、[docs/Git連携設定と同期失敗確認runbook.md](./docs/Git%E9%80%A3%E6%90%BA%E8%A8%AD%E5%AE%9A%E3%81%A8%E5%90%8C%E6%9C%9F%E5%A4%B1%E6%95%97%E7%A2%BA%E8%AA%8Drunbook.md)
- 外部連携・preview: [docs/Webhook設定・送信失敗確認runbook.md](./docs/Webhook%E8%A8%AD%E5%AE%9A%E3%83%BB%E9%80%81%E4%BF%A1%E5%A4%B1%E6%95%97%E7%A2%BA%E8%AA%8Drunbook.md)、[docs/外部フォルダ同期dry-run・apply運用runbook.md](./docs/%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9Fdry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md)、[docs/Microsoft Graph接続とOffice preview.md](./docs/Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)、[docs/Microsoft Graph接続管理runbook.md](./docs/Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md)、[docs/API仕様ページとdocs-src更新確認runbook.md](./docs/API%E4%BB%95%E6%A7%98%E3%83%9A%E3%83%BC%E3%82%B8%E3%81%A8docs-src%E6%9B%B4%E6%96%B0%E7%A2%BA%E8%AA%8Drunbook.md)
- 運用・インフラ: [docs/生成ファイル再試行と定期ジョブ管理runbook.md](./docs/%E7%94%9F%E6%88%90%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E5%86%8D%E8%A9%A6%E8%A1%8C%E3%81%A8%E5%AE%9A%E6%9C%9F%E3%82%B8%E3%83%A7%E3%83%96%E7%AE%A1%E7%90%86runbook.md)、[docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md)、[docs/監視・アラート設計.md](./docs/監視・アラート設計.md)

## 外部サンプル文書

`rails db:seed` は `db/data/*.csv` に加えて、`storage/document_files/external_samples/` 配下の文書も取り込みます。

- 基本の配置規約は `storage/document_files/external_samples/<sample-set>/<site-dir>/...` です。
- `site-dir` ごとに 1 Project を作り、Markdown は 1 ファイルまたは 1 ディレクトリを 1 Document として扱います。
- `README.md` はその階層のトップページとして扱い、`site-dir` 直下の Markdown は current 版、`編集正本` や `提出済` などの配下は別 `DocumentVersion` として取り込みます。
- HTML 表示は Document 詳細から辿れても、公開側の主要 route は `Project: code`、`Document: slug`、`DocumentVersion / DocumentFile: public_id` を使います。
- 標準 showcase は seed 時に `seed-showcase/docs-portal-demo` として再生成されるため、直接編集せず [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を正本にしてください。
- `ai-usecases` は手順書系コンテンツの初期サンプルです。標準 showcase、`ai-usecases`、任意 `external_samples` の役割分担も同じく [標準 seed サンプルと確認用途](./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md) を参照してください。
- Docusaurus build、manual Markdown/MDX preview、Kroki、関連環境変数の runtime 前提は [docs/notes/docusaurus-build-runtime.md](./docs/notes/docusaurus-build-runtime.md) にまとめています。
- PlantUML / D2 を含む Markdown を seed したい場合は Kroki が必要です。compose 切り替えや `.env` の見方は [docs/ローカルセットアップと環境変数.md](./docs/ローカルセットアップと環境変数.md) を参照してください。
- 既存のサンプル文書を持ち込む場合は対象ディレクトリをこの配下へ `cp -r` します。`bin/setup_external_sample_data_links` はベースディレクトリ作成だけを行います。

## 運用メモ

- `storage/imports/` は internal import API が読み取ってよい唯一の import ルートです。`artifact_root` と `manifest_path` はこの配下に置いてください。
- 社外ユーザーの Project 参照は `project_memberships` がある案件に限定されます。
- 社外ユーザーの添付ファイル配信は `DocumentPermission.access_level = download` がある場合だけ許可されます。
- 文書詳細の「表示」リンクは、対応する Docusaurus 生成 HTML が実在する版にだけ出ます。

## サンプルログイン情報

以下は `rails db:seed` が `db/seeds/data/users.csv` から作成するローカル開発 / demo 専用アカウントです。共有環境や本番へ転用する credential ではなく、本番 credential や認証 policy の例でもありません。seed 実行手順と `.env.example` の既定値の読み方は [docs/ローカルセットアップと環境変数.md](./docs/ローカルセットアップと環境変数.md) を参照してください。

| アカウント | seed 上の名前 / 種別 | 最初に見る代表導線 |
| --- | --- | --- |
| `admin@example.com` / `password123!` | 社内管理者 / internal | `/admin` から管理 dashboard と model browser を確認する |
| `staff@example.com` / `password123!` | 社内閲覧者 / internal | `/dashboard` から文書詳細、確認依頼、社内向け導線を確認する |
| `client-a@client-a.example.com` / `password123!` | A商事 担当者 / external | `/dashboard` から閲覧可能文書、アクセス申請、同意画面を確認する |
| `client-b@client-b.example.com` / `password123!` | B物流 担当者 / external | `/dashboard` から閲覧可能文書、アクセス申請、同意画面を確認する |

各導線の詳しい読み方は [docs/管理ダッシュボード・モデルブラウザ運用runbook.md](./docs/管理ダッシュボード・モデルブラウザ運用runbook.md) と [docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md](./docs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md) を参照してください。
