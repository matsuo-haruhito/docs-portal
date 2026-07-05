# API仕様 codeblock dry-run maintenance 境界

このメモは issue `#4593` の first slice として、`Admin::ApiSpecificationsController#codeblock_dry_run` を `READ_ONLY_MAINTENANCE` 中も read-only validation として扱う理由を固定します。

## current support

`codeblock_dry_run` は API 仕様ページ上の HTTP codeblock sample を検証するための dry-run endpoint です。maintenance mode 中も次の payload 境界を維持します。

- `dry_run: true`
- `destructive: false`
- `action_kind: admin_api_spec.http_codeblock_dry_run`
- `target_viewer: admin_api_specification`

この endpoint は request sample の形式確認だけを行い、import、apply、Docusaurus build、外部送信、provider API call、生成済み HTML 配信を開始しません。

## retry_build / stale build enqueue との違い

`READ_ONLY_MAINTENANCE` が有効な間、API 仕様ページでは次の build 起動系操作は開始しません。

- API 仕様ページ表示時の stale build enqueue
- `retry_build` による手動 Docusaurus build 再要求
- `site(/*site_path)` 表示時の stale build enqueue

一方、`codeblock_dry_run` は build 起動ではなく、管理者が表示中の sample を確認する read-only validation として残します。成功時も代表 error 時も `destructive: false` を返し、build request marker を作らないことを request spec で確認します。

## 非目標

この first slice では次を扱いません。

- Docusaurus build pipeline の redesign
- docs-src 内容や generated HTML 配信の変更
- `retry_build` maintenance guard の緩和
- codeblock action 全体の redesign
- external API への dry-run 送信
- production infra 側 maintenance page

## 確認観点

- maintenance mode ON でも path-only internal API sample の dry-run validation が `200` で返る
- maintenance mode ON でも外部 URL sample は `422` の代表 error として返り、外部送信しない理由が読める
- どちらの payload でも `dry_run: true` / `destructive: false` / `target_viewer: admin_api_specification` が維持される
- `ApiSpecificationBuildJob` と build request marker は発生しない
