# リリース・デプロイ・rollback手順

この文書は issue `#149` に対応する、現行 `docs-portal` の標準リリース手順です。

対象は次の構成を前提にします。

- Rails アプリ
- PostgreSQL
- `storage/` 配下の添付ファイル・Docusaurus build 成果物
- GitHub Actions `ci`

本番実行環境が Cloud Run / GCE / VM / コンテナ基盤のどれであっても、ここではアプリ更新時に守るべき順序と確認項目を正本として扱います。

## 1. リリース対象

リリース対象は次の 3 種類に分けます。

1. アプリコード変更
2. migration を含む変更
3. seed / import / build 再実行が必要な変更

単なる view / docs 変更でも、次のどちらかに当たる場合は通常リリース手順に含めます。

- CI 結果を確認してから main へ反映したい場合
- 監査上、いつ何を反映したかを残したい場合

## 2. リリース前チェック

main へ merge する前に最低限確認する項目は次です。

- 対象 PR の CI `test` が成功している
- 変更内容に migration があるか把握している
- `docs/` の仕様変更がコード変更と一致している
- `publish/` `docusaurus/` `attachments/` を変更した場合、再 build / 再 import の要否が整理されている
- rollback 時に DB 差分だけで戻せるか、データ復元が必要かを判断している

## 3. 標準リリース手順

通常の反映順序は次です。

1. main に merge する
2. merge commit の SHA を記録する
3. デプロイ前バックアップを取得する
4. アプリケーションコードを配置する
5. 依存を同期する
6. migration を実行する
7. 必要なら seed / import / build を実行する
8. アプリを再起動する
9. リリース後確認を行う

## 4. デプロイ前バックアップ

デプロイ前には、少なくとも次を取得します。

- PostgreSQL dump
- `storage/` のスナップショット
- 直前リリースの commit SHA

バックアップ手順の詳細は [バックアップ・リストア手順](./バックアップ・リストア手順.md) を参照します。

## 5. 依存更新

アプリ更新時は、現在の repo 構成に合わせて次を同期対象とします。

- Ruby gems
- root `package-lock.json` に紐づく Node 依存
- `docusaurus/package-lock.json` に紐づく Docusaurus 依存

依存更新がある場合の基本手順:

```bash
bundle install
npm ci
cd docusaurus && npm ci
```

本番で root の Node 依存を使わない場合でも、build や補助 script がそれを要求する変更なら同時に更新します。

## 6. migration 実行

migration を含む変更では、アプリ再起動前に `db:prepare` または `db:migrate` を実行します。

原則:

- backward compatible な migration を優先する
- カラム削除・制約強化・一括データ変換は、必要なら段階リリースに分ける
- migration 失敗時はアプリ再起動前に停止し、rollback 判断へ移る

本番で queue / cable / cache DB を分離している場合は、それらを含む production DB 設定の整合も確認します。

## 7. seed / import / build の扱い

変更内容に応じて、次を追加実行します。

### seed

- sample データや初期マスタの仕様を更新した場合のみ必要
- 既存環境への `db:seed` 再実行は `upsert_all` 前提だが、投入対象を事前確認する

### import

- `publish.json` 仕様や import 処理を変えた場合
- 文書 repo から本番取り込みをやり直す必要がある場合

### Docusaurus build

- `docusaurus/` や build script を変えた場合
- 既存成果物を再生成して整合確認したい場合

## 8. リリース後確認

リリース後に最低限見る項目は次です。

- ログイン画面が表示できる
- 社内ユーザーでログインできる
- 案件一覧 / 文書詳細 / HTML 表示 / 添付ダウンロードが壊れていない
- migration を含む場合、対象画面の CRUD が成立する
- import / build を含む場合、最新成果物の閲覧・配信が成立する
- エラーログに即時の例外が出ていない

可能なら次も確認します。

- `Document.latest_version` に影響する画面
- 権限制御が変わる変更なら external view 導線
- `storage/` を参照する配信系 URL

## 9. rollback 方針

rollback は「コードだけ戻す rollback」と「データも戻す restore」を分けて判断します。

### コードだけ戻せるケース

- migration が未実行
- migration が後方互換
- 追加コードだけが不具合原因

手順:

1. 直前の安定 commit に戻す
2. 依存を同期し直す
3. アプリを再起動する
4. リリース後確認をやり直す

### データ restore が必要なケース

- 破壊的 migration を実行済み
- 誤 import / 誤削除 / データ変換失敗が起きた
- `storage/` と DB の整合が壊れた

この場合はコード rollback だけでは不足するため、[バックアップ・リストア手順](./バックアップ・リストア手順.md) に沿って DB と `storage/` を戻します。

## 10. 緊急時の判断基準

次のどれかに当たる場合は、通常の原因調査より rollback を優先します。

- ログインできない
- 文書閲覧または添付ダウンロードが広範囲で失敗する
- 権限不備で情報露出の疑いがある
- migration により主要データが欠損した

一方、限定的な管理画面不具合や docs 表示崩れだけなら、追加 hotfix の方が安全なことがあります。

## 11. 記録しておくべき情報

各リリースで最低限残す情報は次です。

- リリース日時
- 反映 commit SHA
- 実行した migration
- 実行した seed / import / build の有無
- 取得したバックアップ識別子
- rollback 要否の判断結果

### リリース記録テンプレート

リリースごとに、次の template を release record や運用メモへコピーして残します。バックアップ識別子は [バックアップ・リストア手順](./バックアップ・リストア手順.md) の命名方針に合わせ、環境名・日時・commit SHA または release 識別子が分かる値にします。

```markdown
## Release record

- リリース日時:
- 環境:
- 反映 commit SHA:
- 関連 PR / Issue:
- 実行前 CI:
- デプロイ前バックアップ:
  - DB:
  - storage:
  - `bin/verify_backup_artifacts`:
    - DB dump read:
    - storage archive read:
    - required storage prefixes:
    - metadata / strict metadata:
    - warnings:
    - overall result:
    - Markdown summary: 貼り付け先 / record ID
- migration:
  - なし / あり:
  - 実行内容:
  - 破壊的変更の有無:
- seed / import / build:
  - seed: なし / あり:
  - import: なし / あり:
  - Docusaurus build: なし / あり:
- リリース後 smoke:
  - ログイン:
  - 案件一覧:
  - 文書詳細 / HTML 表示:
  - 添付ダウンロード:
  - 変更対象画面:
- rollback 判断:
  - rollback 実施: なし / あり:
  - 実施しなかった理由:
  - コード rollback だけで戻せるか:
  - DB / storage restore が必要か:
  - 使用する rollback target / backup id:
- 追加メモ:
```

破壊的 migration、`storage/` の移動・削除、大量 import / 一括削除を含む場合は、通常の記録に加えて「影響範囲」「復旧に使う backup id」「restore 検証の有無」を同じ record に追記します。GitHub Release、外部監視、deployment automation の利用有無は、この template では前提にしません。

## 12. 現時点の運用ルール

- PR CI が通っていない変更はリリースしない
- migration を含む変更は、バックアップ取得前に本番反映しない
- `storage/` と DB のどちらか片方だけ更新する運用を避ける
- rollback が難しい変更は、小分けの PR / 小分けのリリースに分ける
