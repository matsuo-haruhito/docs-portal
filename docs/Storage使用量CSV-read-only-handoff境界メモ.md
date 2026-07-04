# Storage使用量CSV read-only handoff境界メモ

このメモは、管理ダッシュボードの `Storage使用量` から辿る CSV を、read-only bounded handoff として読むための境界を固定します。

`Admin::StorageUsageController` は、local `Rails.root/storage` 配下の代表 3 領域を HTML / CSV で確認する入口です。CSV は調査のきっかけを渡すための bounded list であり、runtime code、storage cleanup、retention、billing、quota、GCS policy、repair job、CSV full export 化はこのメモの対象外です。

## CSV route

- `admin/storage_usage/document_files`: `DocumentFile` 実体の Project / Document 単位の上位 preview と、紐づく file の read-only handoff を確認します。
- `admin/storage_usage/docs_sites`: `Docs site build` artifact の direct child preview を確認します。
- `admin/storage_usage/imports`: `Import staging` artifact の direct child preview を確認します。

3 route はすべて read-only 確認です。CSV を download できても、削除、cleanup、archive、retention 対象決定、billing / quota 判断、GCS policy 判断、repair 実行、full export decision ではありません。

## CSV header の読み方

- `scope_status`: CSV が `complete_bounded_result` なのか `limited_to_bounded_entries` なのかを示します。`limited_to_bounded_entries` は、続きの全件や削除候補を確定した意味ではありません。
- `display_limit`: 画面 / CSV が代表件数に絞られている境界を示します。調査開始用の上限であり、容量や課金の正本ではありません。
- `safe_relative_path`: raw absolute path を出さず、repo / app 内で安全に読める相対 path preview として扱います。
- `read_only_note`: 行の用途を read-only bounded handoff として明示します。cleanup / delete / archive / retention / billing / quota / GCS policy / repair / full export decision ではありません。

## 空行・0件行の読み方

CSV に `no_entries` 行が出る場合も、対象領域が安全、cleanup 済み、retention 対象なし、billing / quota 問題なし、repair 不要、外部 storage 正常という証明にはしません。

- `DocumentFile` 実体の欠落や登録済み file の確認は、管理ダッシュボードの `文書ファイル健全性` と `欠落ファイル詳細` に戻します。
- `Docs site build` の増加元は、`notes/docusaurus-build-runtime` と build-docs workflow の evidence に戻して確認します。
- `Import staging` の文脈は、manual upload dry-run、ZIP import dry-run、internal upload API の既存 runbook / 画面に戻します。

## 非目標

- storage cleanup / archive / delete / repair job の実装
- retention / billing / quota / GCS policy の策定
- external object storage contract の変更
- CSV full export 化、controller query、CSV header、runtime route、UI redesign
- `StorageUsageSummary` の集計仕様変更
