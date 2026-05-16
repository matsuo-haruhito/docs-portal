# 閲覧画面とUI

この文書は、利用者画面、管理画面、viewer 導線の正本です。

## 画面

- ブランド名クリックで TOP に戻る
- 管理画面は `admin` または `company_master_admin` がアクセス可能とする
- `admin` は全管理機能を利用できる
- `admin` は Project 編集画面から標準文書テンプレートの preview と適用を実行できる
- `admin` は案件単位の文書利用状況レポートを参照できる
- `admin` は管理メニューの「API仕様」から、ドキュメント更新用 internal import API の仕様を参照できる
- API仕様ページは `docs-src/api-specification.md` を Docusaurus build した HTML を same-origin iframe で表示する
- API仕様ページは source Markdown が生成済み HTML より新しい場合に build job を enqueue し、生成HTMLの鮮度確認は `BuildFreshnessGuard` で共通化する
- `company_master_admin` は自社の会社マスタ・自社ユーザー管理のみ利用できる
- 文書詳細では `tree_view` gem を使って「案件 > 文書」の左ペインツリーを表示する
- 文書詳細と版詳細の「添付・元ファイル」は、保持している相対 path を使って `tree_view` でフォルダ階層表示する
- Project 配下で文書カタログ一覧・詳細を表示できる
- 管理画面には、主要 model の件数・最近の record・既存 CRUD への入口を横断表示する `model browser` を持つ
- 403 / 404 / 400 は利用者向けエラー画面で表示し、平文レスポンスにはしない

## 利用者ダッシュボード

- ログイン後に `GET /dashboard` で利用者向けダッシュボードを表示できる
- dashboard には、自分が閲覧可能な案件、お気に入り、後で読む、最近見た文書、最近更新された文書を表示する
- dashboard には、案件数・文書数・保存ショートカット数・保留中申請数などの workspace summary を表示する
- 権限外文書は bookmark や access log に存在しても表示しない

## Markdown preview / version diff

- 版詳細画面は、本文表示、添付、品質チェック、前版との差分確認へ迷わず移動できる preview hub として扱う
- 版詳細画面では、閲覧可能な直前の `DocumentVersion` と比較し、添付・元ファイルの追加、変更、削除件数を表示する
- 差分サマリは、保持済みファイルの `tree_path`、ファイルサイズ、content type、file name を使ったファイル単位の比較から始める
- Markdown本文の行単位diffは、`.md` / `.markdown` の元ファイルを対象に、前版と新版の行差分として表示する
- Markdown本文の行単位diffでは、追加行、削除行、前後コンテキストを unified diff 風に表示する
- 大きすぎるMarkdownファイル、または元ファイルを読み込めない場合は、行単位diffを省略し、理由を利用者へ表示する
- レンダリング後HTML差分は、Docusaurus生成済みHTMLから表示テキストを抽出して表示する
- レンダリング後HTML差分では、script、style、nav、sidebar、footer などの viewer chrome を除外し、本文に近い変更だけを表示する
- HTML本文が未生成、大きすぎる、または読み込めない場合は、HTML差分を省略し、理由を利用者へ表示する
- HTML本文内の table は、表単位・セル単位でも差分を表示する
- 表セル差分では、表追加、表削除、セル追加、セル削除、セル変更を判定して表示する
- 表セル数が多すぎる場合は、表セル差分を省略し、理由を利用者へ表示する
- 差分ビューは Markdown差分、HTML差分、表セル差分へ移動できるタブ風ナビゲーションを持つ
- 差分ビューのタブ、各セクション、Markdownファイル、表ごとに変更件数バッジを表示する
- ブラウザ上でのMarkdown編集保存は後続実装とし、既存画面では preview / diff / 添付 / 品質チェックの閲覧導線を優先する

## Docusaurus viewer

- `GET /projects/:project_code/site/*site_path` および `GET /document_versions/:public_id/site/*site_path` の HTML 応答は、初期表示では viewer shell を返す
- viewer shell は Rails 側の header / breadcrumb / action を持ち、本文部分は same-origin iframe で読み込む
- viewer shell は、本文 iframe の上に preview toolbar を持ち、版詳細、前版との差分、添付・元ファイルへ戻れるようにする
- iframe 側の本文は `embedded=1` 付き同 route を使って取得する
- iframe 側では Docusaurus navbar / footer / toc / sidebar を除去し、本文を中央寄せで表示する
- iframe 側で rewrite される内部 link / asset URL も `embedded=1` を維持する

## Markdown table viewer UX

- HTML viewer shell 内の Markdown table は、表ごとに viewer toolbar を付与し、横長・縦長の表を読みやすくする
- 表 toolbar の拡張は iframe 内の same-origin Docusaurus本文に対して行う
- iframe が将来 cross-origin になった場合でも、table toolbar 拡張に失敗して viewer 表示自体を壊してはならない
- 表幅は表ごとに調整できる
- 表幅は利用者のブラウザに保存し、同じ preview route を開き直しても調整後の幅を維持する
- Markdown table は列境界をドラッグして列幅も調整できる
- 列幅は利用者のブラウザに保存し、同じ preview route を開き直しても調整後の列幅を維持する
- 列幅はキーボードでも調整できるようにする
- 表ごとに先頭行固定を ON / OFF できる
- 表ごとに先頭列固定を ON / OFF できる
- 先頭行固定と先頭列固定は併用でき、左上セルの重なりが崩れないようにする
- 表ごとに表内検索ができる
- 表内検索では一致セルをハイライトし、検索中は一致しない行を折りたたむ
- 表内検索では一致件数を表示し、検索語をクリアできる
- 表ごとに CSV 形式でコピーできる
- 表ごとに Markdown table 形式でコピーできる
- コピー操作では成功・失敗の状態を利用者へ表示する
- 表ごとに表示設定をリセットできる
- 表示リセットでは、表幅、列幅、先頭行固定、先頭列固定の保存値を削除し、現在表示中の表も標準状態へ戻す
- 表 toolbar は、検索、表示、コピーのグループに分けて表示する
- モバイル幅では表 toolbar のグループが縦積みになり、操作が崩れないようにする
- 表幅、列幅、固定表示、検索、コピー、表示リセットはいずれも表示上の利用者個人設定・操作として扱い、Markdown 原文や生成済みHTMLは変更しない
- Markdown table tool の JavaScript は view template に直接長く埋め込まず、フロントエンドモジュールとして保守できるようにする

## DocumentFile viewer registry

- 添付・元ファイルの preview は、ファイル種別ごとの viewer registry で選択する
- viewer registry は、`DocumentFile` の content type、file extension、保持パス、外部同期 metadata、file size、viewer の利用可否を入力にして viewer を決める
- viewer registry は、利用者が閲覧可能なファイルだけを対象にする
- viewer registry は、ファイルを直接表示できない場合でも、理由と代替導線を利用者へ表示する
- viewer registry は、preview 成功・fallback・preview 不可・download only の状態を区別する
- viewer registry の判定は UI から直接分岐させず、サービスまたは presenter に集約する
- viewer registry は、新しい viewer を追加しても既存の添付一覧 UI を大きく変えずに済む構造にする

| 種別 | 主 viewer | fallback / 補足 |
| --- | --- | --- |
| Markdown (`.md`, `.markdown`) | Docusaurus HTML preview | 生成済みHTMLがない場合は source preview / download |
| HTML (`.html`) | same-origin iframe | unsafe / external HTML は download only |
| PDF | PDF preview | 大容量時は download only |
| Office (`.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`) | Microsoft Graph preview | Google Drive sync由来なら Google Drive viewer fallback |
| CSV / TSV | table viewer | 大容量時は sample preview + download |
| JSON / YAML | code viewer / tree viewer | parse不能時は text viewer |
| Text / log | text viewer | 大容量時は head / tail preview + download |
| Image | image viewer | 大容量時は resized preview + download |
| ZIP / archive | archive tree | 展開不可時は download only |
| Unknown binary | download only | preview不可理由を表示 |

- Markdown viewer は、本文 preview、Markdown行diff、HTML差分、表セル差分と連携する
- HTML viewer は、Docusaurus viewer shell と同じ安全な iframe 表示方針に合わせる
- CSV / TSV viewer は、Markdown table viewer UX と同様に検索・コピー・幅調整などを再利用できる設計にする
- JSON / YAML viewer は、将来的に JSON path / YAML path ベースのレビューコメント位置指定と接続できるようにする
- Text / log viewer は、レビューや生成ログ確認のため、行番号表示と行への anchor を持てるようにする
- archive viewer は、ZIP内ファイルを tree view で表示し、個別ファイル preview に viewer registry を再適用できるようにする
- download 権限がない利用者には、download only viewer ではなく権限申請導線を表示する
- preview への遷移は、必要に応じて file view access log として記録する
- viewer registry は、将来の表示対象宣言 metadata と連携し、primary / attachment / hidden / debug などの見せ方を扱えるようにする

## Office file preview

- `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` は Office preview 対象とする
- Office preview は、まず案件ごとの `Microsoft Graph` 接続マスタを使う
- Microsoft Graph 接続が有効な場合、Rails は client credentials flow で access token を取得する
- Rails は対象ファイルを設定済み Drive のプレビュー用フォルダへ一時アップロードし、その driveItem に対して `/preview` を呼び出す
- Microsoft Graph 接続がない場合、または Graph の simple upload 制限を超える場合は、Google Drive 同期由来ファイルに限り Google Drive viewer へ fallback する
- Google Drive fallback は、`ExternalFolderSyncItem#external_item_id` と `provider_metadata.source_mime_type` から `drive.google.com/file/d/:id/preview` または `docs.google.com/.../:id/preview` を生成する
- Google Drive fallback は利用者ブラウザ側の Google アカウント権限に依存するため、ポータル上の閲覧権限だけでは表示できない場合がある
- Microsoft Graph 接続マスタには tenant ID、client ID、client secret、drive ID、プレビュー用フォルダを保存する
- client secret は暗号化カラムに保存する
- 250MBを超えるOffice fileは、Microsoft Graph へはアップロードしない。Google Drive fallback が使える場合は Google Drive viewer を優先し、使えない場合は iframe内に「プレビュー不可・ダウンロードのみ」の案内を表示する
- iframe には Rails の `document_files/:public_id?embedded=1` を読み込ませ、同 route から Graph の preview URL または Google Drive viewer URL へ redirect する
- Graph preview URL は一時 URL として扱い、DB に永続化しない
- Google Drive viewer URL は元ファイルIDから都度生成し、DBには永続化しない
- Office preview への遷移もファイル閲覧として access log を記録する
- Graph preview と Google Drive fallback のどちらも作成できない場合は 502 とし、通常のダウンロード導線は残す

## 危険操作の安全装置

- 危険操作に対して confirm と影響表示を優先する
- admin 画面の delete 操作は `turbo_confirm` 付きで実行する
- 変更前確認導線は、適用処理から分離した dry-run / preview として扱う

## DocumentReviewComment / Q&A

- `DocumentReviewComment` は internal review と公開 Q&A の共通 comment thread として使う
- コメント対象は `Document` と任意の `DocumentVersion` とする
- `internal_only = true` は社内レビュー、`false` は公開 Q&A thread として扱う
- root comment が `comment_type = question` かつ `internal_only = false` のものを Q&A thread として扱う
- external / company_master_admin / internal は、閲覧可能な文書または版の detail 画面から Q&A を投稿できる
- admin はレビューコメントの解決・却下を行える

## 文書カタログ

- `DocumentCatalog` は Project 配下の curated な文書一覧である
- route は `projects/:project_code/document_catalogs/:public_id` を使う
- 一覧では viewer が参照可能な catalog だけ表示する
- 詳細では viewer が参照可能な item だけ表示する

## 文書セット

- `DocumentSet` は Project 配下の用途別 document grouping である
- route は `projects/:project_code/document_sets/:public_id` を使う
- `admin` は管理画面から `DocumentSet` を作成・編集・削除できる
- fixed version を指定しない item は、その `Document` の `latest_version` を使う

## AI向けコンテキスト生成

- Project 単位で AI 向けコンテキスト出力を取得できる
- viewer が参照可能な Document だけを対象にする
- HTML に加えて hash / markdown 形式でも同じ対象を出力できる

## 外部送付履歴

- 文書または文書セット単位で、外部送付の履歴を `DocumentDeliveryLog` として記録する
- 利用者は自分が作成した履歴を参照できる
- admin は全履歴を参照し、状態変更や確認を行える
