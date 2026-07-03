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
- 管理ダッシュボードの `Storage使用量` で local storage 配下の概算使用量、file count、直下項目ごとの大きい内訳、`DocumentFile` 実体の Project / Document 上位 breakdown、`storage/docs_sites` / `storage/imports` の bounded detail を read-only に確認できる

### GCS 等のオブジェクトストレージ

- bucket / prefix 設計が必要
- object existence は API 越しに確認する
- signed URL かアプリ経由配信かを選ぶ必要がある

当面の方針:

- path / prefix 設計はローカル path 構造を踏襲する
- public access は禁止する
- 配信可否の判定はアプリ側に残す
- `Storage使用量` は local directory scan と `DocumentFile` metadata に基づく read-only preview であり、GCS / object storage API の疎通確認や課金レポートとして扱わない

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
- `Storage使用量` に数字や大きい内訳、bounded detail が出ても、それだけで削除、archive、cleanup、retention policy 決定へ進まない

## 9. storage 使用量の考え方

管理ダッシュボードの `Storage使用量` は、local `Rails.root/storage` 配下の概算使用量を read-only に確認する入口です。

current support の対象:

- `storage/document_files`: アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本
- `storage/docs_sites`: Docusaurus などで生成した文書表示用 site artifact
- `storage/imports`: ZIP / manual upload dry-run などの一時確認 artifact

画面では、各領域の file count と概算 byte size、3 領域の合計を確認できます。さらに各領域の `大きい内訳` として、直下項目ごとの file count と概算使用量を大きい順に最大 5 件まで表示します。内訳の path は `storage/<area>/<child>` 形式の relative path で、raw absolute path は通常 UI に出しません。

`Docs site build detail` と `Import staging detail` は、`storage/docs_sites` / `storage/imports` の直下項目を最大 25 件まで詳しく見る bounded detail です。表示するのは safe relative path、項目の読み方、file count、概算使用量、最終更新、read-only cue に閉じます。Project / build version / import job との厳密な対応付け、全件 export、cleanup 判断、delete / archive / retention / billing / quota / GCS policy の判断や実行はここでは行いません。

`DocumentFile 実体の Project / Document 上位` は、`storage/document_files` に紐づく `DocumentFile` metadata と実体 file size を照合し、Project / Document 単位の概算上位 5 件を read-only に表示します。表示項目は Project code/name、Document title/slug、file count、実体欠落件数、概算使用量、最終更新に閉じます。実体が欠落している file は欠落件数だけに入り、raw absolute path は表示しません。

`DocumentFile 実体 storage detail` は、上位 5 件だけではなく、登録済み `DocumentFile` 実体を bounded にたどる read-only detail です。表示するのは Project / Document / safe relative path / file count / 概算使用量 / 最終更新 / missing count までで、raw absolute path、credential、private path、signed URL、GCS bucket identifier は表示しません。表示上限に達した場合も、全件 export や削除判断ではなく、容量増加時に次に見る Project / Document / path の手掛かりとして扱います。

`大きい内訳` は local storage の直下ディレクトリや直下ファイルが容量の目立つ入口になっているかを見る補助表示です。`Docs site build detail` と `Import staging detail` は、その直下項目を少し詳しく読むための bounded preview です。`DocumentFile 実体の Project / Document 上位` は DocumentFile metadata と照合した所有者別 preview で、`DocumentFile 実体 storage detail` は同じ DocumentFile 実体を bounded に掘り下げる調査入口です。いずれも削除対象、archive 対象、cleanup 対象、retention policy 対象を確定する画面ではありません。

`内訳なし` や detail の 0 件表示は、現在の条件で表示できる直下項目または DocumentFile breakdown がない状態を表します。正常保証、cleanup 完了、retention 対象なし、外部 storage 側の容量 0 を意味しません。

`文書ファイル健全性` / `欠落ファイル詳細` は、登録済み `DocumentFile` の実体が見えるかを確認する入口です。一方、`Storage使用量` は local storage 領域別の概算容量、直下内訳、docs_sites / imports detail、DocumentFile 実体の Project / Document 上位 preview、DocumentFile 実体 storage detail を確認する入口です。欠落ファイルの修復対象や削除対象を決める画面ではありません。

current support 外:

- `storage/docs_sites` / `storage/imports` の Project / Document / 顧客単位の容量内訳
- 顧客単位の容量レポート
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
- `大きい内訳` は local storage の直下項目 top 5 の補助表示として読み、cleanup 候補一覧として扱わない
- `Docs site build detail` と `Import staging detail` は、直下項目の bounded detail として読み、Project / build version / import job との厳密な対応付けや cleanup 判断として扱わない
- `DocumentFile 実体の Project / Document 上位` は、DocumentFile 実体に閉じた所有者別 preview として読み、課金レポート、顧客別容量レポート、削除・retention 判断として扱わない
- `DocumentFile 実体 storage detail` は、DocumentFile 実体を bounded に掘り下げる read-only detail として読み、欠落ファイルの修復、削除、archive、retention、billing、quota、GCS policy の判断や実行として扱わない
- cleanup 自動化は retention と restore 手順を先に決めてから導入する
