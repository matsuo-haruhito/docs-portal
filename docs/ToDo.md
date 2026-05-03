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

- archived からの復元操作を社内向けに実装する
- archive 操作時の警告文言を UI に追加する
  - 「アーカイブ操作をすると、本システムの提供元に依頼しなければ復元できません」
- archived version を通常導線に出さないことを request spec で確認する

## Import / GitHub Actions

- `publish/documents.json` から `publish.json` を生成するスクリプトを整備する
- GitHub Actions を 1 本化し、build -> manifest 生成 -> import API まで通す
- artifact の永続保存方式を検討する
- バージョン管理しない Document の上書き import を実装する
- semantic version 比較で latest_version を更新する処理を実装する

## Docusaurus / seed

- seed 用 Docusaurus build で id front matter を自動付与する処理を安定化する
- seed 用 Markdown build 失敗時のログを見やすくする
- Docusaurus asset の MIME type を実機確認し、必要なら `.js` / `.css` の明示マップを追加する

## テスト

- company_master_admin の権限制御 request spec を追加する
- public_id route の request spec を追加する
- latest_version の semantic version 比較 spec を追加する
- archived の非表示・復元 spec を追加する
- AccessLog の記録対象 spec を追加する
