# ToDo

この文書には、現時点の仕様には含めないが、将来検討・実装する可能性があるものを記載する

仕様として確定したものは、該当する docs 文書へ移動する

## 権限・管理画面

- `company_master_admin` 向けの管理画面導線を実装する
  - 自社ユーザー管理
  - 自社会社マスタ管理
  - 他社情報・案件・文書・文書権限へアクセスできないことを確認する
- `internal` と `admin` の分離を UI / route / controller で徹底する
- 管理画面でも DB id ではなく public_id / code / slug を使うようにする
- 正式なレビュー・承認ワークフローを導入するかは、コメント・品質チェック・公開制御・送付運用が固まってから再評価する
- 形式的な workflow とは別に、最小確認依頼 / OK・Cancel 機能は独立 issue で扱う

## UI / UX

- dashboard / navbar / viewer shell / admin model browser の基礎導線は実装済み
- 社内 / 社外 / 管理者ごとの導線差分は、必要になったタイミングで画面群ごとに個別 issue へ分けて扱う
- 総合 UI/UX 見直しは包括 issue として残さず、必要になった時点で viewer / dashboard / navigation / admin UX など具体 issue に分けて扱う
- 本文表示の改善は viewer 単位の issue を優先し、全画面の大規模 redesign は後回しにする

## public_id / URL

- 外部公開 route を public_id / code / slug へ移行する
  - Project: code
  - Document: slug
  - DocumentVersion: public_id
  - DocumentFile: public_id
- numeric id 直指定 route を段階的に廃止する

## latest_version / バージョン管理

- semantic version 以外の任意バージョン記号に対応するか検討する
- `latest_version` を管理画面/APIで明示指定できるようにするか検討する
- 採番ルールを変更した場合に、古い DocumentVersion を整理・削除・archive する運用を検討する
- バージョン管理しない Document の上書き運用を UI/API 上で明確にする

## archived / 復元

- Document 単位 archive / restore は admin 管理画面で実装済み
- retention / discard candidate を使った一覧・一括操作・自動通知は後続

## Import / GitHub Actions

- `publish/documents.json` から `publish.json` を生成するスクリプトを整備する
- GitHub Actions を 1 本化し、build -> manifest 生成 -> import API まで通す
- artifact の永続保存方式を検討する
- バージョン管理しない Document の上書き import を実装する
- `latest_version` の明示切り替えや別ルール更新を入れる場合は、現行の created_at 基準との差分を整理してから扱う

## Docusaurus / seed

- seed 用 Docusaurus build で id front matter を自動付与する処理を安定化する
- seed 用 Markdown build 失敗時のログを見やすくする
- embedded viewer 前提での iframe 高さ追従や document-site 内検索など、本文 UX を追加検討する

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

- company_master_admin の権限制御 request spec を追加する
- public_id route の request spec を追加する
- latest_version の created_at 基準と override 方針が変わる場合は、そのルールを request / service spec に追加する
- AccessLog の記録対象 spec を追加する
