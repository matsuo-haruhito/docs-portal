# AGENTS

この repo の作業前提は、この `AGENTS.md`、[Product Profile.md](./Product%20Profile.md)、[docs/README.md](./docs/README.md) を正本として扱うことです。

## このrepo固有の運用

- 作業前に `docs/README.md` を入口として `docs/` 配下の関連文書を確認すること。
- repo の位置づけや関連 repo との責務境界を短く確認したい場合は `Product Profile.md` を読むこと。
- 実装や判断に影響する repo 固有ルールは `docs/` を正本として扱うこと。
- 仕様整理、実装判断、運用メモ、コーディング規約の明文化がこのrepoで有用だと判断した場合は、`docs/` 配下の既存文書を同一ターンで加筆修正するか、必要に応じて新規作成すること。
- `docs/` に新規文書を追加した場合は、入口として `docs/README.md` も同一ターンで更新すること。

## AI / 開発者向けの読み順

- まず `Product Profile.md` と `docs/README.md`、次に `docs/アプリケーション仕様.md`、`docs/テスト方針.md`、関連 runbook を読むこと。
- 構成や責務分離を把握したい場合は `docs/開発・保守ガイド.md` を参照すること。
- 実装確認は、関連する controller / service / spec に限定して読むこと。広く全件走査しないこと。

## 主要ディレクトリの当たり先

- 画面・導線: `app/controllers/`, `app/views/`
- 管理画面: `app/controllers/admin/`
- import / export / search / preview 系の責務: `app/services/`
- import 本体: `app/importers/`
- seed と Docusaurus build 補助: `db/seeds.rb`, `db/seeds/support/`
- request spec: `spec/requests/`
- service / importer spec: `spec/services/`, `spec/importers/`

## 読み飛ばしてよいことが多い場所

- `docs/ai/prompt-logs/` は今回タスクの履歴確認が必要な場合だけ読むこと。
- `storage/docs_sites/` や `storage/document_files/` の実データは、配信不具合や seed/import を調べる時だけ見ること。
- `app/policies/` は現時点では最小利用なので、Pundit 実装調査が目的でない限り優先度は低い。
