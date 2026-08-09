# Runbooks

操作手順書（runbook）を領域別に分類して管理するディレクトリ。

---

## viewer/

利用者（external user）向けの閲覧・操作手順。

- [文書カタログ閲覧runbook](./viewer/文書カタログ閲覧runbook.md)
- [文書ショートカット運用runbook](./viewer/文書ショートカット運用runbook.md)
- [利用者向け確認依頼runbook](./viewer/利用者向け確認依頼runbook.md)
- [利用者向けアクセス申請runbook](./viewer/利用者向けアクセス申請runbook.md)
- [利用者向け同意画面・同意履歴runbook](./viewer/利用者向け同意画面・同意履歴runbook.md)
- [版詳細プレビュー・差分・添付確認runbook](./viewer/版詳細プレビュー・差分・添付確認runbook.md)
- [ZIPプレビューと個別ダウンロード確認runbook](./viewer/ZIPプレビューと個別ダウンロード確認runbook.md)
- [グローバルナビ分類・開閉導線runbook](./viewer/グローバルナビ分類・開閉導線runbook.md)
- [text-preview-line-anchor-target-cue](./viewer/text-preview-line-anchor-target-cue.md)

## admin/

管理者（internal admin）向けの文書・権限・マスタ運用手順。

- [文書マスタ運用runbook](./admin/文書マスタ運用runbook.md)
- [文書一覧の検索・実用フィルタ・ZIP出力runbook](./admin/文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
- [文書コメント・Q&A運用runbook](./admin/文書コメント・Q&A運用runbook.md)
- [rails_fields_kit文書マスタ案件選択runbook](./admin/rails_fields_kit文書マスタ案件選択runbook.md)
- [監査ログ運用runbook](./admin/監査ログ運用runbook.md)
- [文書一括編集dry-run運用runbook](./admin/文書一括編集dry-run運用runbook.md)
- [company_master_admin会社・ユーザー管理runbook](./admin/company_master_admin会社・ユーザー管理runbook.md)
- [案件所属・文書権限運用runbook](./admin/案件所属・文書権限運用runbook.md)
- [文書セット運用runbook](./admin/文書セット運用runbook.md)
- [文書利用状況運用runbook](./admin/文書利用状況運用runbook.md)
- [版品質チェックrunbook](./admin/版品質チェックrunbook.md)

## import/

インポート・ビルド・同期操作の手順。

- [ZIPインポートdry-run運用runbook](./import/ZIPインポートdry-run運用runbook.md)
- [案件・Git連携・文書セット初回セットアップrunbook](./import/案件・Git連携・文書セット初回セットアップrunbook.md)
- [build-docs workflow確認runbook](./import/build-docs%20workflow確認runbook.md)
- [Git連携設定と同期失敗確認runbook](./import/Git連携設定と同期失敗確認runbook.md)
- [手動アップロード差異確認runbook](./import/手動アップロード差異確認runbook.md)
- [internal upload API dry-run・apply運用runbook](./import/internal%20upload%20API%20dry-run・apply運用runbook.md)

## external/

外部連携（フォルダ同期・Webhook・送付履歴・Graph接続・MCP）の運用手順。

- [OAuth 2.0・MCP接続runbook](./external/OAuth%202.0・MCP接続runbook.md)

- [外部フォルダ同期dry-run・apply運用runbook](./external/外部フォルダ同期dry-run・apply運用runbook.md)
- [外部フォルダ同期継続失敗候補runbook](./external/外部フォルダ同期継続失敗候補runbook.md)
- [外部送付履歴運用runbook](./external/外部送付履歴運用runbook.md)
- [外部送付履歴継続失敗候補runbook](./external/外部送付履歴継続失敗候補runbook.md)
- [アクセス申請・同意管理・Webhook運用runbook](./external/アクセス申請・同意管理・Webhook運用runbook.md)
- [Webhook設定・送信失敗確認runbook](./external/Webhook設定・送信失敗確認runbook.md)
- [Microsoft Graph接続管理runbook](./external/Microsoft%20Graph接続管理runbook.md)

## ops/

運用・インフラ・定期メンテナンスの手順。

- [管理ダッシュボード・モデルブラウザ運用runbook](./ops/管理ダッシュボード・モデルブラウザ運用runbook.md)
- [生成ファイル再試行と定期ジョブ管理runbook](./ops/生成ファイル再試行と定期ジョブ管理runbook.md)
- [生成ファイル継続失敗候補runbook](./ops/生成ファイル継続失敗候補runbook.md)
- [AI向けコンテキストexport運用runbook](./ops/AI向けコンテキストexport運用runbook.md)
- [API仕様ページとdocs-src更新確認runbook](./ops/API仕様ページとdocs-src更新確認runbook.md)
- [Markdown table toolbar運用runbook](./ops/Markdown%20table%20toolbar運用runbook.md)
- [関連gem連携調査runbook](./ops/関連gem連携調査runbook.md)
- [バックアップ・リストア手順](./ops/バックアップ・リストア手順.md)
- [リリース・デプロイ・rollback手順](./ops/リリース・デプロイ・rollback手順.md)
- [情報露出smoke evidence運用メモ](./ops/情報露出smoke%20evidence運用メモ.md)
- [文書利用状況未利用handoffメモ](./ops/文書利用状況未利用handoffメモ.md)
- [生成ファイル再試行UI-cue補足](./ops/生成ファイル再試行UI-cue補足.md)
- [社外ユーザー向け情報露出点検チェックリスト](./ops/社外ユーザー向け情報露出点検チェックリスト.md)
- [管理画面nav領域見出し運用メモ](./ops/管理画面nav領域見出し運用メモ.md)
- [運用metadata情報露出点検チェックリスト](./ops/運用metadata情報露出点検チェックリスト.md)
