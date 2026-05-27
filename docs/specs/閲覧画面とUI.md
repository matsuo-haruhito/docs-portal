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
- 文書一覧と文書詳細の左ペイン `文書ツリー` では、current project 内の文書名・slug・元パスを使って文書を絞り込める
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
- Markdown本文の行単位diffは、 `.md` / `.markdown` の元ファイルを対象に、前版と新版の行差分として表示する
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
- 版詳細画面の hero、workspace 見出し、補助文言は Markdown 専用固定にせず、版種別に関わらず「版詳細の確認ハブ」であることが先に伝わる表現を優先する
- read-only の版詳細画面では、操作不能な編集風 toolbar や、押せないのに押せそうに見える control を置かない
- タブ風ナビゲーションや mode 切り替えを置く場合は、現在地表示か、実際に移動できる導線だけで構成する
- `添付・元ファイル` の分類表示は、internal key をそのまま見せず、利用者向けラベルと内部分類値を分ける

## Docusaurus viewer

- `GET /projects/:project_code/site/*site_path` および `GET /document_versions/:public_id/site/*site_path` の HTML 応答は、初期表示では viewer shell を返す
- viewer shell は Rails 側の header / breadcrumb / action を持ち、本文部分は same-origin iframe で読み込む
- viewer shell は、本文 iframe の上に preview toolbar を持ち、版詳細、前版との差分、添付・元ファイルへ戻れるようにする
- iframe 側の本文は `embedded=1` 付き同 route を使って取得する
- iframe 側では Docusaurus navbar / footer / toc / sidebar を除去し、本文を中央寄せで表示する
- iframe 側で rewrite される内部 link / asset URL も `embedded=1` を維持する
- viewer shell は same-origin iframe の本文高さに追従し、初期表示後や画像・遅延コンテンツ読込後に本文が伸びても二重スクロールを常態化させない
- embedded HTML 側は親 viewer へ本文高さを通知し、viewer shell 側は同一 origin の iframe にだけその高さ更新を反映する
- viewer shell の hero、toolbar、aria label は portal 全体の表示言語に合わせ、利用者向け文言へそろえる
- viewer shell では、版詳細、差分、添付・元ファイル、品質などの戻り先を action / link として明示し、静的な疑似タブだけを残さない
- viewer shell の現在地表示をタブ風に見せる場合も、非アクティブ項目は link にするか plain な current-state 表示に留め、押下不能な control に見せない

## Docusaurus build profiles

- Docusaurus build は用途別 profile を持てるようにする
- build profile は、qaboard の Web アプリ埋め込み用 build と webdriverio の生成前処理・strict link check の考え方を docs-portal 向けに整理したものとして扱う
- build profile は `url`、`baseUrl`、`routeBasePath`、navbar / footer / sidebar の有無、broken link policy、前処理、出力先を切り替える
- build profile は環境変数または明示的な build command で選択し、暗黙の分岐を避ける

想定 profile:

| profile | 用途 | 主な違い |
| --- | --- | --- |
| `portal_embedded` | Rails viewer shell の iframe 内表示 | navbar / footer / toc / sidebar を最小化、same-origin route 前提、`embedded=1` 互換 |
| `standalone_public` | 将来の単体公開サイト | navbar / footer / search を有効化、canonical URL を外部公開向けに設定 |
| `admin_api_spec` | 管理画面のAPI仕様 | internal import API docs を生成前処理で更新、admin viewer に最適化 |
| `preview_check` | 標準文書テンプレート preview / apply 前確認 | strict link check、metadata validation、差分用 artifact 生成 |
| `diff_metadata` | 版差分・品質チェック補助 | HTML本文抽出、見出し一覧、table index、codeblock index などを生成 |

- `portal_embedded` では、Rails 側の viewer shell が navigation を担うため、Docusaurus 側の chrome は最小化する
- `standalone_public` では、Docusaurus 側の navbar、footer、search、version dropdown を有効化できるようにする
- `admin_api_spec` では、API仕様 Markdown の生成前処理を build 前に実行し、生成元が新しい場合は `BuildFreshnessGuard` で build job を enqueue する
- `preview_check` では、broken links、存在しない metadata path、旧 path 参照、通常表示ファイル0件などを警告またはエラーにする
- `diff_metadata` では、viewer runtime で重い解析を避けるため、見出し、code block、table、内部 link の index を生成できるようにする
- broken link policy は profile ごとに変える
  - internal preview は warning 中心
  - external publish / preview apply は error 中心
  - archived version は warning 中心
- build profile の出力には、profile 名、source commit、build time、Docusaurus version、validation result を manifest として保存する
- viewer shell は manifest を参照し、build profile 不一致や stale build を利用者へ表示できるようにする
- build profile は Project / DocumentVersion / API仕様などの利用箇所ごとに既定値を持てるようにする
- 将来的に複数 docs plugin / route 分割を導入する場合も、profile ごとに docs root と sidebar を選択できるようにする

## Codeblock actions

- Docusaurus viewer 内の code block には、内容や言語に応じて利用者向け action を付与できるようにする
- codeblock actions は、API仕様、手順書、運用マニュアル、import API のサンプルで使いやすさを上げるための viewer 拡張として扱う
- codeblock actions は Markdown 原文や生成済みHTMLを変更せず、viewer shell または iframe 内拡張として提供する
- codeblock actions は、コピーなどの即時操作と、dry-run / 検証などのサーバー連携操作を区別する
- サーバー連携操作は、権限判定、CSRF対策、実行前確認、結果表示、access log を必須とする
- サーバー連携操作は、既定では destructive な処理を実行せず、dry-run / validation から始める

想定 action:

| 対象 | action | 補足 |
| --- | --- | --- |
| `curl` | コピー | token や secret らしき値は mask された表示を優先する |
| `json` | JSONコピー / 整形コピー / validation | API request sample や metadata sample に使う |
| `yaml` / `yml` | YAMLコピー / validation | preview target metadata や workflow sample に使う |
| `bash` / `sh` | コマンドコピー | 複数行コマンドは1つの script としてコピーできる |
| `npm` / `yarn` / `pnpm` | package manager 切り替え | Docusaurus実例の npm/yarn切り替えに相当する |
| `http` | request sample コピー / dry-run | internal import API のサンプル検証に使う |
| `ruby` / `rails` | コマンドコピー | admin向け運用手順に使う |
| unknown | copy only | 言語不明でも最低限コピーは提供する |

- copy action はブラウザ clipboard API を使い、成功・失敗を code block 近くに表示する
- copy action は iframe が same-origin の場合に有効化し、cross-origin の場合は viewer 表示を壊さず無効化する
- secret、token、password、authorization header などを含む可能性がある code block は、自動実行や外部送信の対象にしない
- dry-run action は、対象 API・操作種別・入力内容・実行ユーザーを明示してから実行する
- dry-run 結果は、成功 / 警告 / エラーを code block 下に表示し、必要なら詳細ログを折りたたむ
- import API dry-run は、実際の文書更新を行わず、作成予定の Project / Document / DocumentVersion / DocumentFile の概要を返す
- codeblock action は、レビューコメントの anchor と連携できるように、code block id、言語、行番号を持てるようにする
- code block 内の特定行に対して internal review comment を付けられるようにする
- codeblock action の表示有無は、文書種別、利用者権限、code language、metadata に応じて制御できるようにする
- admin は API仕様ページの codeblock action を dry-run で検証できる
- external 利用者には copy 系 action を中心に表示し、server-side dry-run は必要な権限がある場合だけ表示する
- action 実行時には、対象文書版、site path、code block id、action kind、結果を access log または audit log に残せるようにする

## Path history / redirect

- 文書 slug、Docusaurus site path、添付・元ファイル tree path は、外部共有済みURLや社内bookmarkを壊さないため、履歴を持てるようにする
- path history は、現在の canonical path と過去の alias path を区別する
- 旧URLへアクセスした場合、閲覧権限を確認した上で canonical URL へ誘導する
- redirect は権限判定より前に情報を漏らしてはならない
- 権限がない旧URLでは、現在の文書名や移動先を表示せず、通常の権限エラーまたは申請導線を表示する
- canonical URL へ誘導できる場合は 301 ではなく、まずは 302 / 303 など安全な一時 redirect として扱う
- path history は、削除済み・アーカイブ済み・移動済みを区別する
- 移動済み文書では、viewer shell または文書詳細に「この文書は移動しました」という notice を出せるようにする
- アーカイブ済み文書では、最新版や後継文書がある場合に代替先を表示する
- 削除済み文書では、代替先が明示されている場合だけ案内し、それ以外は通常の not found とする

対象:

| 対象 | 例 | 履歴の用途 |
| --- | --- | --- |
| Document slug | `/projects/:project_code/documents/:slug` | 文書名変更・整理後も旧URLを維持する |
| Docusaurus site path | `/projects/:project_code/site/docs/old-page` | Markdown path / generated HTML path 変更後も旧URLから本文へ誘導する |
| DocumentVersion site path | `/document_versions/:public_id/site/docs/old-page` | 版ごとの生成済みHTML内リンクを壊しにくくする |
| DocumentFile tree path | `attachments/old/name.pdf` | 添付・元ファイルの移動やrename後も履歴・差分・metadataを追いやすくする |
| Catalog / Set item path | curated list item | 文書カタログや文書セットの旧参照を保つ |

- Document slug history は Project 内で一意に扱う
- Docusaurus site path history は Document または DocumentVersion の scope 内で一意に扱う
- DocumentFile tree path history は DocumentVersion 内で一意に扱う
- 新しい path が既存 alias と衝突する場合は保存時にエラーまたは品質チェック警告を出す
- path history は preview target metadata の `primary`、`attachments`、`hidden`、`debug`、`groups.paths` の解決にも使えるようにする
- metadata の path pattern が旧 path に一致する場合、品質チェックで canonical path への更新候補を出す
- 任意版比較では、tree path の変更を単純な削除・追加だけでなく、可能なら rename / moved として扱えるようにする
- access log は、アクセスされた元URLと解決後の canonical target の両方を記録できるようにする
- admin は slug / path 変更前に dry-run で影響範囲を確認できるようにする
- dry-run では、旧URL数、catalog / set 参照、preview target metadata、内部リンク、外部送付履歴への影響を表示する

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

## Preview target metadata

- 文書版は、添付・元ファイルを利用者へどう見せるかを宣言する preview target metadata を持てるようにする
- preview target metadata は、qaboard の visualization 定義のように、表示対象、グループ、既定表示、非表示対象を宣言するための metadata として扱う
- preview target metadata は Markdown 原文や生成済みHTMLを直接変更せず、docs-portal 側の viewer / 添付一覧 / 文書セット表示を整理するために使う
- metadata がない文書版では、従来通り全ての閲覧可能な `DocumentFile` を tree path 順に表示する
- metadata に存在しないファイルも、権限があれば「その他」または元ファイル一覧から到達できるようにし、利用者がファイルを失わないようにする

例:

```yaml
preview:
  primary: docs/index.md
  attachments:
    - specs/*.pdf
    - tables/*.csv
  hidden:
    - debug/*
    - intermediate/*
  debug:
    - logs/*
    - generated/*.json
  groups:
    - name: API仕様
      description: 外部連携に必要な仕様書
      paths:
        - api/*.md
        - openapi/*.json
    - name: 参考資料
      paths:
        - references/*
```

- `primary` は文書版の主要 preview として扱う
- `attachments` は利用者へ通常表示する添付・元ファイルとして扱う
- `hidden` は通常の添付一覧では折りたたみ、必要に応じて表示できるようにする
- `debug` は社内向け・開発者向けの生成物やログとして扱い、既定では非表示にする
- `groups` は添付・元ファイル一覧や文書セット詳細での見出しとして使う
- `groups.paths` は glob 風の path pattern とし、保持済み `tree_path` に対して評価する
- `primary` / `attachments` / `hidden` / `debug` に指定されたファイルにも、最終的な表示可否は通常の権限判定を適用する
- metadata は viewer registry と連携し、各 path に対して適切な viewer を選択する
- metadata の不正な path pattern、存在しない path、重複指定は品質チェックで警告する
- metadata により通常表示されるファイルが0件になる場合は、品質チェックで警告する
- admin は標準文書テンプレートの preview / apply 前に、metadata による表示結果を dry-run で確認できる
- 将来的には Project / DocumentSet / DocumentVersion 単位で既定 metadata を上書きできるようにする

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
- `admin` は管理画面の `admin/document_sets` 一覧で `rails_table_preferences` ベースの表示設定 UI を開ける
- `admin/document_sets` 一覧の table preference key は `admin_document_sets` で固定する
- 一覧の表示設定 UI と table 本体は同じ `document_set_table_columns` を参照し、`project`、`name`、`set_type`、`visibility_policy`、`documents_count`、`actions` の各列を `data-rails-table-preferences-column-key` で対応付ける
- fixed version を指定しない item は、その `Document` の `latest_version` を使う

## AI向けコンテキスト生成

- Project 単位で AI 向けコンテキスト出力を取得できる
- viewer が参照可能な Document だけを対象にする
- HTML に加えて hash / markdown 形式でも同じ対象を出力できる

## 外部送付履歴

- 文書または文書セット単位で、外部送付の履歴を `DocumentDeliveryLog` として記録する
- 利用者は自分が作成した履歴を参照できる
- admin は全履歴を参照し、状態変更や確認を行える