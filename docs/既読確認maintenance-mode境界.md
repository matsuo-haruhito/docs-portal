# 既読確認 maintenance-mode 境界

このメモは、利用者の既読確認操作を `READ_ONLY_MAINTENANCE` 中にどう読むかを整理する。文書利用状況の集計や既読確認内訳の読み方は [文書利用状況運用runbook](./文書利用状況運用runbook.md) を正本にし、このメモでは maintenance mode 中の変更停止境界だけを扱う。

## Current support

`ReadConfirmationsController#create` と `#destroy` は `READ_ONLY_MAINTENANCE` を boolean cast し、maintenance mode ON では `ReadConfirmation` を保存・削除しない。

停止するもの:

- 利用者が文書詳細などから `既読にしました` を保存する操作
- 利用者が既存の既読確認を `既読を解除` として削除する操作

残すもの:

- 文書閲覧そのもの
- 管理側の `文書利用状況` 画面での案件単位集計確認
- 管理側の `既読確認内訳` 画面での確認日時、確認者、会社、文書 slug の read-only 確認

停止時の alert は、既読確認の変更だけを停止し、文書閲覧と既読確認内訳の確認は継続できることを説明する。

## 非目標

この境界は既読確認の作成・削除だけを対象にする。次は current support として追加しない。

- 既読義務、通知、SLA、正式承認 workflow の導入
- 文書利用状況集計や KPI 定義の変更
- 既読確認内訳 filter、pagination、CSV の仕様変更
- 全利用者向け変更系操作の一括停止
- `ReadConfirmation` model、route、request spec、controller 実装の変更

## 確認順

1. 利用者向けの既読操作が maintenance mode ON で保存・削除されないことは `ReadConfirmationsController` を確認する。
2. 文書利用状況と既読確認内訳の見方は [文書利用状況運用runbook](./文書利用状況運用runbook.md) を確認する。
3. maintenance mode の変更系操作 inventory は [本番運用・インフラ前提](./本番運用・インフラ前提.md) の `変更系操作 inventory` を確認する。
