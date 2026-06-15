# ファイル配信・storage運用方針

この文書は issue `#142` に対応する、`docs-portal` のファイル配信と storage 周辺の現行方針です。

## 1. 取り扱うファイル種別

本アプリは次を扱います。

- Docusaurus HTML
- JS / CSS / image asset
- Markdown 生ファイル
- PDF
- text / csv / json / yaml
- ZIP
- 画像

## 2. 保存先の役割

現行の責務分担:

- `storage/document_files/`: 添付・元ファイル
- `storage/docs_sites/`: Docusaurus build 成果物
- `storage/imports/`: import artifact staging

## 3. ローカル storage と GCS の差分

### ローカル storage

- `Rails.root/storage/...` を直接参照する
- `send_file` で配信する
- file existence を同期的に確認できる
- 管理ダッシュボードの `Storage使用量` で local storage 配下の概算使用量、file count、直下項目ごとの大きい内訳を read-only に確認できる

### GCS 等のオブジェクトストレージ

- bucket / prefix 設計が必要
- object existence は API 越しに確認する
- signed URL かアプリ経由配信かを選ぶ必要がある

当面の方針:

- path / prefix 設計はローカル path 構造を踏襲する
- public access は禁止する
- 配信可否の判定はアプリ側に残す
- `Storage使用量` は local directory scan の結果であり、GCS / object storage API の疎通確認や課金レポートとして扱わない

## 4. MIME type / charset 方針

`DocumentFile#effective_content_type` は、拡張子ベースで次を補正します。

- `.md` / `.markdown`: `text/markdown`
- `.txt`: `text/plain`
- `.csv`: `text/csv`
- `.json`: `application/json`
- `.yml` / `.yaml`: `text/yaml`
- `.html`: `text/html`

`text/*` は `charset=utf-8` を付与します。

このため、現時点のルールは次です。

- Markdown / text / csv / yaml は UTF-8 charset 付き
- PDF は `application/pdf`
- JSON は `application/json`
- HTML asset は `text/html`
- JS / CSS asset は `Rack::Mime.mime_type` に従う

## 5. inline / attachment 方針

`DocumentFile` は次を inline 対象とします。

- PDF
- image/*
- text/*
- application/json

それ以外は attachment を基本にします。

`Content-Disposition` header は、ASCII fallback に加えて UTF-8 の `filename*` も付け、日本語ファイル名の download 互換性を確保します。

## 6. missing file 時の挙動

### 添付ファイル

`DocumentFilesController#show` は、解決済み path が存在しなければ `404 File not found` を返します。

### site build

Docusaurus site は `DocusaurusSiteRenderer` と `ProjectSitesController` / `DocumentSitesController` 側で path を検証し、対象 page が見つからなければ `RecordNotFound` として扱います。

### import

`DocumentImporter` は次を明示的に失敗させます。

- build directory not found
- attachment not found
- import root 外の path

## 7. path 安全性

現行コードでは次を防いでいます。

- `storage_key` の絶対 path
- `../` による path traversal
- `document_files` ルート外への脱出
- import root 外の artifact / manifest 参照

このため、GCS 移行時も「prefix 外参照を許さない」制約を維持します。

## 8. cleanup 方針

整理対象:

- import 一時展開物
- build 作業ディレクトリ
- 生成済み SVG
- 失敗 import artifact

現時点の方針:

- `storage/document_files` と `storage/docs_sites` は正本または復旧対象として扱う
- `storage/imports` は長期保管前提にしない
- cleanup の自動化は、誤削除防止のため retention 付きで設計する
- `Storage使用量` に数字や大きい内訳が出ても、それだけで削除、archive、cleanup、retention policy 決定へ進まない

## 9. storage 使用量の考え方

管理ダッシュボードの `Storage使用量` は、local `Rails.root/storage` 配下の概算使用量を read-only に確認する入口です。

current support の対象:

- `storage/document_files`: アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本
- `storage/docs_sites`: Docusaurus などで生成した文書表示用 site artifact
- `storage/imports`: ZIP / manual upload dry-run などの一時確認 artifact

画面では、各領域の file count と概算 byte size、3 領域の合計を確認できます。さらに各領域の `大きい内訳` として、直下項目ごとの file count と概算使用量を大きい順に最大 5 件まで表示します。内訳の path は `storage/<area>/<child>` 形式の relative path で、raw absolute path は通常 UI に出しません。

`大きい内訳` は、どの直下ディレクトリや直下ファイルが容量の目立つ入口になっているかを短く切り分けるための補助表示です。これは Project 単位、Document 単位、顧客単位の容量レポートではなく、`DocumentFile` metadata と照合した所有者別集計でもありません。

`内訳なし` は、現在の条件で表示できる直下項目がない状態を表します。正常保証、cleanup 完了、retention 対象なし、外部 storage 側の容量 0 を意味しません。

`文書ファイル健全性` / `欠落ファイル詳細` は、登録済み `DocumentFile` の実体が見えるかを確認する入口です。一方、`Storage使用量` は local storage 領域別の概算容量と直下内訳を確認する入口です。欠落ファイルの修復対象や削除対象を決める画面ではありません。

current support 外:

- Project / Document / 顧客単位の容量内訳
- `DocumentFile` metadata と照合した所有者別集計
- CSV export / 定期レポート
- cleanup、archive、自動削除、retention policy 決定
- GCS bucket、signed URL、public access policy、object storage API の確認

## 10. 監視との接続

監視対象として見るべきもの:

- missing file 件数
- storage 使用量
- GCS API 失敗
- import attachment copy 失敗
- site build 欠落

current repo では、storage 使用量は管理ダッシュボードの `Storage使用量` で read-only に確認できます。通知 channel、alert rule、外部監視サービス連携はまだ具体実装ではないため、画面で見える概算使用量と監視 alert 実装を混同しないでください。

詳細は [監視・アラート設計](./監視・アラート設計.md) を参照します。

## 11. 現時点の運用ルール

- storage 配信判定はアプリ側に残す
- object storage 利用時も public access は許可しない
- missing file は 404 に統一し、原因は運用ログで追う
- MIME type / charset は `DocumentFile#effective_content_type` を正本として扱う
- 管理ダッシュボードの `Storage使用量` は read-only な容量確認入口として扱い、削除・archive・cleanup・retention policy 判断の実行入口にしない
- `大きい内訳` は local storage の直下項目 top 5 の補助表示として読み、Project / Document / 顧客単位の容量レポートや cleanup 候補一覧として扱わない
- cleanup 自動化は retention と restore 手順を先に決めてから導入する
