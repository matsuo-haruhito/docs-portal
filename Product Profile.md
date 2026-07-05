# Product Profile

## 位置づけ

`docs-portal` は、案件ごとの社外秘ドキュメント配布を Rails + Docusaurus で運用するためのポータルアプリです。

この repo は、文書公開ポータル本体として次を一体で扱います。

- 案件ごとの文書公開
- Document / DocumentVersion / DocumentFile の版管理
- internal / external user の閲覧権限制御
- 添付ファイル配布
- import / preview / build / 外部フォルダ同期 / webhook などの運用導線

## 主な利用者

- internal の admin / staff
  - 案件、文書、権限、公開状態、運用ジョブ、外部連携を管理する
- external user
  - 許可された案件と文書を閲覧し、必要に応じて添付ファイルをダウンロードする
- maintainer / contributor
  - 仕様 docs、runbook、関連 gem との責務境界を確認しながら portal 本体を保守する

## この repo の責務

- Rails ポータル本体の画面、導線、認可、公開モデルを保守する
- Docusaurus build を公開成果物として扱う current runtime と import 導線を保守する
- Google Drive 外部フォルダ同期、internal import API、Webhook など app 本体の運用境界を保守する
- `READ_ONLY_MAINTENANCE` 中に止める変更操作と read-only に残す確認導線を、current code、request spec、runbook で同期する
- README、`docs/`、runbook を通じて current app behavior の正本を整える

## この repo の責務外

- `tree_view`、`rails_table_preferences`、`rails_fields_kit` の public API 自体は各 gem repo を正本とする
- 法務判断、顧客合意、承認基準そのものはこの repo で新規定義しない
- 外部フォルダ同期は current 実装では portal への片方向取り込みであり、汎用双方向同期基盤を目的にしない

## 参照優先順位

1. current code
2. `docs/README.md` を入口にした仕様 docs / runbook
3. `AGENTS.md`
4. この `Product Profile.md`

`Product Profile.md` は repo の位置づけと責務境界を短く共有するための入口であり、詳細仕様の正本は `docs/` 配下を優先します。

## 最初に見る文書

1. [AGENTS.md](./AGENTS.md)
2. [docs/README.md](./docs/README.md)
3. [docs/アプリケーション仕様.md](./docs/アプリケーション仕様.md)
4. [docs/開発・保守ガイド.md](./docs/開発・保守ガイド.md)
5. [docs/本番運用・インフラ前提.md](./docs/本番運用・インフラ前提.md) - `READ_ONLY_MAINTENANCE`、本番 health check、storage / import / build / 外部連携の運用境界を確認するときの入口
6. タスクに対応する個別仕様 / runbook

## 関連 repo

- `matsuo-haruhito/tree_view-rails`
  - 案件 / 文書ツリー表示の UI と責務境界
- `matsuo-haruhito/rails_table_preferences`
  - 一覧表示設定と table UX の共通基盤
- `matsuo-haruhito/rails_fields_kit`
  - 検索可能 select や入力補助などの form UI 基盤

これらの詳細 API や導入前提は各 repo の README / docs を参照し、`docs-portal` 側では組み込み方と運用上の確認点を正本にします。`docs-portal` 側で代表画面の smoke、pinned ref 更新、rollback target、host app と上流 gem の責務境界を確認する場合は、[internal UI gem adoption evidence map](./docs/internal-ui-gem-adoption-evidence-map.md)、[internal UI gem 責務境界 matrix](./docs/internal-ui-gem責務境界matrix.md)、[internal UI gem packaging gate runbook](./docs/internal-ui-gem-packaging-gates.md)、[internal UI gem release train target matrix](./docs/internal-ui-gem-release-train-target-matrix.md)、[関連 gem 連携調査 runbook](./docs/関連gem連携調査runbook.md) を入口にします。
