# ToDo

この文書には、現時点の仕様には含めないが、将来検討・実装する可能性があるものを記載する。

仕様として確定したものは、該当する docs 文書へ移動する。具体 Issue があるものは、この文書に要件を重複して残さず、Issue 番号と正本 docs への導線だけを残す。

未起票のまま残す項目は、まだ起票しない理由を短く添える。実装痛点、運用要件、顧客確認、または対象画面が具体化した時点で、1 つの concrete issue に切り出す。

## 権限・管理画面

- `company_master_admin` の current `/admin` redirect と `会社` / `ユーザー` 管理の制約は [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md) を正本とし、ここには未解決の導線改善だけを残す
- 管理画面でも DB id ではなく public_id / code / slug を使うようにする。未起票で残す理由: 対象 route と互換影響を棚卸ししてから concrete issue に分ける必要がある
- 正式なレビュー・承認ワークフローを導入するかは、コメント・品質チェック・公開制御・送付運用が固まってから再評価する。未起票で残す理由: ワークフロー仕様の正誤判断が必要
- 形式的な workflow とは別に、最小確認依頼 / OK・Cancel 機能は独立 issue で扱う。未起票で残す理由: 対象画面と通知要件が具体化してから切る

## UI / UX

- dashboard / navbar / viewer shell / admin model browser の基礎導線は実装済み
- 社内 / 社外 / 管理者ごとの導線差分は、必要になったタイミングで画面群ごとに個別 issue へ分けて扱う
- 総合 UI/UX 見直しは包括 issue として残さず、必要になった時点で viewer / dashboard / navigation / admin UX など具体 issue に分けて扱う
- 本文表示の改善は viewer 単位の issue を優先し、全画面の大規模 redesign は後回しにする

## public_id / URL

- 公開側の主要 route は `code` / `slug` / `public_id` へ移行済み。管理画面や internal 導線の numeric id 直指定 route は段階的に廃止する。未起票で残す理由: 管理画面 route ごとの互換性を確認してから小さく切る

## latest_version / バージョン管理

- `version_label` は semantic version として解釈・sort せず、任意の表示用ラベルとして扱う。`2026-Q2` / `review-2026-05` / `client-a-draft` のような label を importer から受けても opaque label として保存する current contract は `#1050` で spec 固定する
- `latest_version` は current では published version の作成・更新時に promoted される。管理画面/API/import manifest で明示指定できるようにするかは後続判断として残す。未起票で残す理由: 手動切り替えの権限・監査・UI 要件が未確定
- 採番ルールを変更した場合に、古い DocumentVersion を整理・削除・archive する運用を検討する。未起票で残す理由: retention 方針と復元要件の判断が必要
- importer は latest version 上書き、手動アップロードは `manual-*` draft 候補を追加して review で `latest_version` を切り替える current 差分を、どこまで統一するか再判断する。手動アップロード契約の first slice は `#758` で扱う

## archived / 復元

- Document 単位 archive / restore は admin 管理画面で実装済み
- retention / discard candidate を使った一覧・一括操作・自動通知は後続。未起票で残す理由: 保存期間、通知先、復元期限の方針判断が必要

## Import / GitHub Actions

- current の manifest 生成手順と `build-docs` workflow の確認順は [build-docs workflow確認runbook](./build-docs%20workflow確認runbook.md) を正本とし、ここでは未完了論点だけを残す
- artifact の永続保存方式と再取り込み replay 方針は `#1039` で扱う
- `latest_version` の明示切り替えや別ルール更新を入れる場合は、現行の created_at 基準との差分を整理してから扱う。未起票で残す理由: `latest_version` 明示指定の要件と同じ判断に依存する

## Docusaurus / seed

- seed 用 Docusaurus build で id front matter を自動付与する処理の安定化は `#1040` で扱う
- seed 用 Markdown build 失敗時のログ改善は `#1022` / PR `#1036` で扱う。current runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) を正本にする
- embedded viewer 前提の iframe 高さ追従 first slice は `#1020` で扱う。本文内検索 UI は、browser native search で足りない痛点が具体化した時点で別 issue に分ける

## 多言語 / localization

- 多言語版管理は、実際に同一文書の多言語運用需要が出てから再評価する
- 初期に導入する場合でも、翻訳自動生成より先に `language` と翻訳文書の関連付け導線を検討する
- Docusaurus viewer / Rails preview / 検索 / カタログ / コメントとの結合点が増えるため、独立した具体 issue に分けてから着手する

## Job / 運用自動化

- 長時間処理の自動リトライは初期実装で入れない
- import / build / mail / webhook の失敗傾向が本番で見えてから、処理ごとの冪等性と二重実行リスクを確認したうえで要否を再評価する
- 自動リトライを検討する場合も、対象処理ごとに separate issue を切り、手動再実行で十分かを先に判断する
- 長時間処理の job 化や再生成導線は、親 umbrella issue を維持せず、実際に同期 request を塞いでいる処理や運用痛点が明確になった時点で concrete issue を起こす
- import / build の job 化は、同期 import/build 導線を本当に置き換える時点で再評価する
- mail / webhook の job 化は、送信機能本体が先に固まってから再評価する
- 再生成 rails task / job 履歴は、検索再生成や build 再生成の実需要が出た時点で具体対象ごとに起票する

## 品質・運用改善の扱い

- test / CI / import-build robustness / external dependency stability / performance / DB integrity / observability は、今後も必要に応じて継続改善する
- ただし `安定化を進める` `強化する` のような broad umbrella issue は原則として維持しない
- 追加対応が必要になった時は、次のように concrete issue に分けて扱う
  - failing or flaky spec の修正
  - import/build/mail/webhook の個別 job 化と履歴
  - specific N+1 / slow query / index 追加
  - migration safety / constraint 追加
  - viewer / build / Kroki / npm version pin の個別修正
  - structured logging / error reporting / admin failure inspection の個別導線
- 既に着手済みの slice:
  - 利用者向け 403 / 404 / 400 エラー画面
  - 主要 request spec の拡充
  - trigram index による検索改善
  - classification / viewer / security / file-delivery 周辺の docs 整理
- 残件は umbrella issue ではなく、再現した問題や具体的な改善対象ごとに起票する

## 依存 gem の導入方針

- vendor / author 単位の網羅調査 issue は維持しない
- gem 導入は concrete use-case ごとに判断する
  - params 正規化
  - nested form
  - import 補助
  - admin SQL viewer
  - 型生成
- 新しい gem を入れる時は、Rails 標準や既存依存で代替できない理由、運用コスト、導入範囲を一緒に記録する
- 現時点で導入済みの `rparam` / `rtypes` 以外は、必要機能が出たタイミングで個別 issue から判断する

## テスト

- latest_version の created_at 基準と override 方針が変わる場合は、そのルールを request / service spec に追加する。未起票で残す理由: product contract が決まってから test issue に切る