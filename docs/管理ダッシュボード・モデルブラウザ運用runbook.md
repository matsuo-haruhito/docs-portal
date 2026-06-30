# 管理ダッシュボード・モデルブラウザ運用runbook

この runbook は、管理画面の `ダッシュボード` と `モデルブラウザ` を日常運用で見返すときの入口をまとめる。

新しい診断ルールや監視基準はここでは定義しない。current 実装を前提に、`モデル観測` `アプリ設定診断` `文書ファイル健全性` `Storage使用量` をどう使い分け、必要に応じてどこへ戻るかを整理する。

## 先に見るもの

1. 環境変数や compose の前提を確認したいときは [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
2. Docusaurus build や Kroki の runtime 前提を確認したいときは [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
3. `storage/document_files` や欠落ファイル時の扱いを確認したいときは [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
4. 管理画面の位置関係は `app/views/admin/_nav.html.slim` の `ダッシュボード` と `モデルブラウザ` を起点に確認する

## 画面の役割

`admin/dashboard` は internal admin だけが使える運用確認の入口で、`モデル観測` `アプリ設定診断` `文書ファイル健全性` `Storage使用量` を 1 画面で見比べる。

current 実装の前提:

- `モデル観測` は `Admin::ModelBrowserCatalog.entries.first(8)` を並べ、主要な model だけを最初に見せる
- `アプリ設定診断` は `ApplicationConfigurationDiagnostic` の check を `OK / 警告 / エラー` 件数つきで出す
- `文書ファイル健全性` は `DocumentFileHealthCheck` で総件数と実体欠落件数を出し、欠落ファイルは最大 20 件まで一覧表示する
- 欠落ファイルがある場合、`欠落ファイル詳細` で案件、文書名 / slug、Storage key / ファイル名の断片から絞り込みながら、先頭 100 件まで read-only に確認できる
- 欠落ファイル詳細の案件 filter は、案件コード / 案件名で検索する remote search として表示され、候補は最大 20 件まで返る。選択済み案件は候補上限外でも form / summary に復元される
- 欠落ファイル詳細の `Expected path` は raw absolute path ではなく、`storage/document_files/...` 形式の safe preview として表示される
- `Storage使用量` は `StorageUsageSummary` で local `storage/document_files` / `storage/docs_sites` / `storage/imports` の file count と概算使用量を read-only に出す
- `Storage使用量` の `大きい内訳` は、各領域の直下項目を bytes / file count / 最終更新つきで上位 5 件まで表示する read-only preview として扱う。`storage/docs_sites` と `storage/imports` もここで増加元の当たりを付けられる
- `Storage使用量` の `DocumentFile 実体の Project / Document 上位` は、`storage/document_files` に紐づく `DocumentFile` 実体だけを Project / Document 単位で概算集計し、上位 5 件を read-only preview として表示する
- `Storage使用量` の `次の確認先` は、各領域から既存確認画面や既存 docs へ戻るための link cue であり、削除、cleanup、retention 対象を確定する操作ではない
- `Storage使用量` の `次の確認先` に `この行は read-only 集計です` と出る行は、追加導線の未設定ではなく、その行の file count / 概算使用量を読むだけの領域として扱う
- `運用失敗入口` は、生成ファイルや外部送付履歴などの保存済み failed 履歴と、同じ identity の最新 run が連続 failed かを見る `継続失敗候補` を分けて表示する
- `保存済み履歴` の件数は保存済み failed 履歴の件数であり、継続失敗候補、通知状態、ack 状態、自動復旧状態とは別に読む
- `古い失敗のみ` は 7 日より古い対象履歴だけが残っている cue であり、緊急度、通知状態、ack 状態を示す表示ではない
- 画面下部の `基本マスタ` `関連設定` は、日常確認後に既存の管理画面へ戻る近道として置かれている

## 1. モデル観測とモデルブラウザ

### ダッシュボード側で見ること

- `モデル観測` カードは、会社・ユーザー・案件・案件所属・文書などの主要 model について、件数と最終更新をざっと確認するために使う
- ここで「件数が急に増減していないか」「直近でどの領域が更新されたか」を把握してから、必要なら詳細へ進む
- dashboard から見えるのは catalog の先頭 8 件だけなので、周辺 model まで横断したいときは `モデルブラウザを開く` へ進む

### モデルブラウザ側で見ること

`admin/model_browser` は catalog に載っている model を一覧し、各 model の件数・最終更新・最近の record を read-only に確認する画面。

current 実装の前提:

- index では各 model の `件数` と `最終更新` を、`基本マスタ` `文書・権限` `取り込み・同期` `外部連携` `運用` の領域別 group に分けて並べる
- index の `モデル検索` は、catalog entry のモデル名、key、説明、group の表記から model を探すための入口であり、最近の record 自体を検索する欄ではない
- index の検索語は前後空白を除いて最大 100 文字まで使う。空白だけの入力は検索条件なしとして扱い、filter 済み状態や 0 件 state にしない
- index の検索 0 件 state では、`モデル検索` が catalog entry 検索であることを読み、record 名、public_id、code を探したい場合は対象 model の詳細に進んで `代表フィールド検索` を使うか、既存管理画面で確認する
- group は `Admin::ModelBrowserCatalog::GROUP_LABELS` と各 entry の `group` metadata が正本で、画面側だけで分類を作らない
- show では model ごとに最近 20 件の record を、catalog が持つ `summary_fields` で表示する
- show の `代表フィールド検索` は、各 model の `summary_fields` のうち実カラムの string / text field と、数字だけの検索語では `id` exact match を対象にする
- association 表示用の `*_id` field は代表フィールド検索の対象外だが、`public_id` は識別用の代表 field として検索対象に残る
- `*_id` field は、関連先 record から `display_name` / `name` / `title` / `code` / `public_id` / `email_address` の短い label を安全に取れる場合だけ、`表示名（ID: 123）` のように label と ID を併記する
- 関連先 label が取れない、関連 record がない、または association reflection が取れない場合は、従来どおり ID 値または `-` の短い表示へ戻る。関連先検索、row action、record detail 導線をここで追加したものではない
- 検索語は最大 100 文字に切り詰められ、検索結果も最大 20 件までの read-only sample として表示される
- index の検索結果から詳細へ入った場合、detail の `モデル一覧へ戻る` と breadcrumb は index 側の検索語を保持したモデル一覧へ戻る。detail 内の `代表フィールド検索` を解除しても、元の index 検索文脈は残る
- `既存画面へ` がある model は、そのまま管理画面の一覧へ戻れる
- show の `既存画面で詳しく確認` は、対象 model が query handoff allowlist に入っており、検索語が数値だけではない場合だけ、代表フィールド検索の語を既存画面の検索条件に引き継ぐ。それ以外は検索語をコピーして対象画面で再確認する
- `DocumentVersion` `DocumentFile` など既存の専用 index がないものも、ここでは最新 record の代表値を見返せる
- モデルブラウザには編集、削除、bulk action、CSV export、pagination、saved search はない。続きの検索や操作が必要な model は `既存画面へ` から専用管理画面へ戻る

領域別 group の読み方:

- `基本マスタ`: 会社・ユーザー・案件のように、他の管理対象の起点になる master data を見る
- `文書・権限`: 文書、版、ファイル、文書権限、同意、アクセス申請、監査ログなど、公開・閲覧・download 条件に近い model を見る
- `取り込み・同期`: Git 取り込み、外部フォルダ同期、一括編集 dry-run など、取り込みや同期の実行・事前確認に関わる model を見る
- `外部連携`: Webhook、外部フォルダ同期購読、外部 viewer preview upload など、外部 service との接点を持つ model を見る
- `運用`: 定期ジョブや実行履歴など、日常運用の状態確認に使う model を見る

使い分け:

- まず変化の有無をざっと見たい: `ダッシュボード`
- model 全体の件数や最終更新を横断で比較したい: `モデルブラウザ` index
- 領域別に近い model をまとめて見たい: `モデルブラウザ` index の group 見出し
- catalog に載っている model を名前、key、説明、group から探したい: `モデルブラウザ` index の `モデル検索`
- `モデル検索` が 0 件のとき: model 名、key、説明、group の表記を変えて再検索し、record 名や public_id を探している場合は対象 model の詳細または既存画面へ切り替える
- index の検索結果から detail へ入ったあと元の model 一覧へ戻りたい: detail の `モデル一覧へ戻る` または breadcrumb から、検索済みの index へ戻る
- 最近の record の shape や値を短く確認したい: `モデルブラウザ` show
- 最近の record のうち public ID、名称、code など代表フィールドに心当たりがある値だけを探したい: `モデルブラウザ` show の `代表フィールド検索`
- detail の代表フィールド検索から既存画面で続けたい: `既存画面で詳しく確認` が検索語を引き継ぐ場合はそのまま確認し、引き継がない場合や数値だけの検索語では公開ID・code など画面で確認できる値を使って既存画面で再確認する
- 編集や登録をしたい: `モデルブラウザ` ではなく `既存画面へ` から元の管理画面へ戻る

### Catalog を追加・見直すとき

`Admin::ModelBrowserCatalog` は、dashboard の `モデル観測` と `admin/model_browser` が参照する model 一覧の正本。新しい model や運用画面を追加したときは、catalog に載せるか、既存の専用管理画面だけで十分かを先に分ける。

追加判断の目安:

- 日常運用で件数・最終更新・最近の record を横断確認したい model は catalog 候補にする
- 既存の専用管理画面があっても、dashboard や model browser から全体変化を見たい model は catalog に残す
- 中間テーブルや履歴 model は、障害調査やデータ整合確認で最近の record を見る意味がある場合だけ載せる
- UI や workflow の新規仕様を catalog だけで表現しない。編集・再実行・承認などの操作は既存管理画面や専用 runbook の正本へ戻す

`group` の選び方:

- まず既存の `GROUP_LABELS` から、運用者が最初に探す領域に最も近い group を選ぶ
- master data や所属の起点なら `basic_master`、文書公開・権限・同意・アクセス履歴に関わるなら `document_permission` を優先する
- import、sync、dry-run、外部フォルダの実行履歴は `import_sync`、Webhook や外部 viewer upload など外部 service との接点は `external_integration` に寄せる
- 定期ジョブや運用状態確認の model は `operations` に寄せる
- group を増やす判断は、この runbook だけではなく catalog entry 全体の分類と index 見出しの読みやすさを見て Issue / PR で扱う

`summary_fields` の選び方:

- `public_id`、状態、種別、関連先 ID、時刻など、最近の record を識別しやすい短い値を優先する
- `secret`、token、authorization、raw payload、request / response body、長大 text、個人情報の本文相当は入れない
- ファイル本文、Webhook request body、外部 API の raw response などは、model browser ではなく専用のマスク済み preview や詳細画面の方針に従う
- association は `*_id` のような短い参照値に留める。model browser show では安全に取れる関連先 label と ID を短く併記する場合があるが、代表フィールド検索の対象や関連先詳細への操作導線にはしない
- 代表フィールド検索は string / text の `summary_fields` と numeric `id` の補助検索に限られるため、検索させたい値を増やす目的だけで長大 text や secret 相当の field を `summary_fields` に追加しない

`summary_fields` 追加時の guard の読み方:

- `spec/services/admin/model_browser_catalog_spec.rb` の `does not expose secret-like or raw diagnostic fields in summary metadata` が、catalog の安全境界を固定している current guard
- guard は `secret` / `token` / `password`、`authorization` / `header`、`payload` / `body` / `raw`、`request` / `response` 風の field 名が `summary_fields` に混ざらないことを見る
- guard に引っかかった場合の first response は、mask helper を model browser に足すことではなく、その field を catalog から外すか、`public_id`、status、短い ID、時刻などの識別用 field に置き換えること
- current allowlist は `webhook_deliveries.response_status` だけで、HTTP status code の短い値であり response body、header、payload ではない理由が spec に残っている
- allowlist を増やす必要がある場合は、この runbook だけで判断せず、spec 側に「なぜ raw diagnostic ではないか」を残し、model browser が raw payload 調査画面ではない境界を維持する

`index_path_helper` の考え方:

- 既存の一覧管理画面で編集・絞り込み・再実行などを扱う model は `index_path_helper` を持たせ、model browser から `既存画面へ` で戻れるようにする
- `DocumentVersion`、`DocumentFile`、履歴・購読・preview upload など専用 index がない model は、model browser show で read-only に最近の record を確認する入口として扱う
- `index_path_helper` がないことは欠落とは限らない。操作画面を新設する判断は、この runbook ではなく対象機能の Issue / PR で扱う

Dashboard との関係:

- dashboard の `モデル観測` は `entries.first(8)` の主要 model だけを見せる概要であり、catalog 全体の網羅表ではない
- index の領域別 group は model browser で横断しやすくするための見出しであり、dashboard の先頭 8 件表示順を置き換えるものではない
- 先頭 8 件の順序を変えると dashboard の見え方も変わるため、catalog の並び替えは dashboard で最初に見せたい model の優先度も含めて確認する

## 2. アプリ設定診断

`アプリ設定診断` は、起動に必要な前提や sample 値の流用を current app がどう見ているかを一覧で返す。

current 実装の前提:

- 必須環境変数では `DATABASE_*` `ACTIVE_STORAGE_SERVICE` `PUBLISH_WEB_SERVER_PORT` と Active Record encryption key 群を確認する
- 数値項目では `DATABASE_PORT` `PUBLISH_WEB_SERVER_PORT` `RAILS_MAX_THREADS` が整数として解釈できるかを確認する
- secret 系では `SECRET_KEY_BASE` `RAILS_MASTER_KEY` `DOC_IMPORT_TOKEN` を確認し、sample 値のままなら warning または error にする
- storage / workspace 系では `config/storage.yml` に `ACTIVE_STORAGE_SERVICE` が存在するか、`storage/document_files` に書き込めるか、`docusaurus/package.json` があるか、`KROKI_ENDPOINT` が前提と合っているかを確認する
- `補足` 列には問題になっている値や path が出ることがある
- status filter は `すべて / OK / 警告 / エラー` で表示行だけを絞り込む。診断 rule や全体 summary の集計条件は変えない
- category filter は `秘密値 / Storage / Workspace / 環境変数` で表示行だけを絞り込む。分類は current diagnostic の既存 category 表示を読むためのもので、新しい診断 rule を足すものではない

見方:

- `OK` は current 前提を満たしている
- `警告` は今すぐ致命傷ではないが、sample 値の流用や optional service 前提の不足がある
- `エラー` は起動や build、import、preview に直結する不足で、先に解消したい項目
- status / category filter は、原因の種類や優先して見る状態を絞り込むために使う。`すべて` に戻すと診断項目全体の一覧へ戻る
- 上部の `OK / 警告 / エラー` summary は診断全体の件数として読み、`全X件中Y件を表示` は現在の filter 条件に合う表示行数として分けて読む
- filter 0 件は「現在の絞り込み条件に一致する診断項目がない」状態であり、診断全体が healthy という意味ではない。全体の状態は summary を確認する
- 無効な status / category param は `すべて` 扱いに戻るため、URL 共有や手入力後に想定外の filter が残っていないかは画面上の選択状態で確認する

戻り先:

- `.env.example` 基準の設定値や compose 切り替えを見直したいときは [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
- Docusaurus workspace や Kroki 前提を見直したいときは [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
- `ACTIVE_STORAGE_SERVICE` や `storage/document_files` の扱いを見直したいときは [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)

## 3. 文書ファイル健全性

`文書ファイル健全性` は、登録済み `DocumentFile` に対応する実体ファイルが app から見えているかを確認する。

current 実装の前提:

- `登録ファイル数` は `DocumentFile` 総数
- `実体欠落` は `DocumentFile#absolute_path` に実ファイルが存在しなかった件数
- dashboard の欠落一覧は最大 20 件までで、`案件` `文書` `版` `ファイル名` `Storage key` を表示する
- 欠落ファイルがある場合は `欠落ファイル詳細` へ進むと、先頭 100 件まで `Expected path` preview を含めて確認できる
- 欠落ファイル詳細では `案件`、`文書名 / slug`、`Storage key / ファイル名` で絞り込める。案件は案件コード / 案件名の remote search で候補を探し、候補は最大 20 件まで表示される。これらは欠落ファイルだけを対象にした read-only filter であり、修復対象や削除対象を確定する操作ではない
- 欠落ファイル詳細の `条件をクリア` は、`案件`、`文書名 / slug`、`Storage key / ファイル名` のいずれかが有効なときだけ表示される。空白だけの検索語は条件なしに正規化され、解除導線や `条件一致欠落` の対象にはならない
- 欠落状況では `登録ファイル数`、`全体の実体欠落`、filter 中の `条件一致欠落`、`表示中` を分けて読む
- 一覧の `文書` は公開側の project/document detail、`版` は document version detail へ戻れる
- dashboard 表示時点の current 実装は `DocumentFile` を `find_each` で走査する。cache / async 化はこの runbook ではなく、ファイル数がさらに増えたときの別 Issue で判断する

読み方:

- `実体欠落` が 0 でないときは、まず dashboard の先頭 20 件で欠落が特定案件だけか、複数案件へ広がっているかを見る
- 欠落が 20 件を超える、または path preview まで含めて確認したい場合は `欠落ファイル詳細` へ進む
- 特定案件だけを確認したい場合は `案件` filter を使う。案件 filter は案件コード / 案件名の断片で候補を探し、候補は最大 20 件まで表示されるため、候補に出ない場合は検索語を具体化する。URL や戻り導線で選択済み案件が指定されている場合は、候補上限外でも selected project として復元される
- 文書名や slug の心当たりがある場合は `文書名 / slug`、storage key や file name の断片がある場合は `Storage key / ファイル名` を使う
- `条件をクリア` が出ていない状態は、有効な filter がない状態として読む。空白だけの `文書名 / slug` や `Storage key / ファイル名` を送って戻った場合も条件なしに正規化されるため、全体の欠落状況だけを見る
- filter 中の `条件一致欠落: 0` は「全体に欠落がない」ではなく、現在の条件に一致する欠落がない状態として読む。全体の有無は `全体の実体欠落` を見る
- `条件一致欠落` が `表示中` より多い場合、詳細一覧は条件一致分の先頭 100 件だけを表示している。続きを見るには条件を絞るか、storage 側または database 側の調査へ切り替える
- `Storage key` は登録済み `DocumentFile` が持つ保存先 key、`Expected path` preview はその key から組み立てた `storage/document_files/...` 形式の確認用表示として読む
- `Expected path` preview は root directory や raw absolute path を通常 UI に出さないため、preview だけで不足する場合は `Storage key`、文書・版リンク、storage 側または database 側の調査を組み合わせる
- `文書` や `版` へ戻り、対象が current 版か添付・原本か、import 直後の版かを確認する
- `実体欠落` が詳細一覧の表示件数より多い場合、詳細一覧も先頭 100 件の bounded list として扱い、続きを見るには storage 側や database 側の調査へ切り替える

注意点:

- この check は app が参照する filesystem 上で `File.file?` を見る current 実装であり、外部ストレージ API の疎通確認まではしない
- 欠落ファイル詳細は read-only であり、自動修復、削除、archive、再import、CSV export は扱わない
- filter は表示対象を絞るだけで、retention policy、cleanup、復元期限、GCS / object storage 連携の判断は行わない
- 権限不足や公開条件の問題を診断する画面ではなく、まず「物理ファイルが見えるか」を切り分けるための入口として使う

## 4. Storage使用量

`Storage使用量` は、local `Rails.root/storage` 配下の領域別 file count と概算使用量を read-only に確認する。

current 実装の前提:

- `DocumentFile 実体` は `storage/document_files` を測り、アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本を読む
- `Docs site build` は `storage/docs_sites` を測り、Docusaurus などで生成した文書表示用 site artifact を読む
- `Import staging` は `storage/imports` を測り、ZIP / manual upload dry-run などの一時確認 artifact を読む
- 各領域は `StorageUsageSummary` が directory 内の file を走査して、file count と `number_to_human_size` の概算使用量にする
- 各領域の `大きい内訳` は直下項目単位の上位 5 件だけを表示し、file count、概算使用量、最終更新を read-only preview として読む。raw absolute path は表示しない
- directory が存在しない場合は 0 file / 0 byte として扱う
- `合計` はこの 3 領域の合算として読み、Project / Document 単位の内訳は別枠の `DocumentFile 実体の Project / Document 上位` で見る
- `DocumentFile 実体の Project / Document 上位` は、`storage/document_files` に紐づく `DocumentFile` 実体だけを Project / Document 単位で概算集計する。表示は上位 5 件に限定され、Project code/name、Document title/slug、file count、実体欠落件数、概算使用量、最終更新を読むための read-only preview として扱う
- 実体が存在しない file は `実体欠落` 件数に入り、raw absolute path は表示されない。欠落の詳細調査は `文書ファイル健全性` / `欠落ファイル詳細` へ戻す
- `次の確認先` は、各領域の数値を見たあとに既存の詳細画面や運用 docs へ戻るための入口であり、dashboard 上で削除、archive、cleanup、retention policy 決定へ進める操作ではない
- `次の確認先` が `この行は read-only 集計です` の行は、追加の詳細画面や docs へ移動せず、その領域の file count / 概算使用量だけを確認する行として扱う

読み方:

- 容量の増減をざっと見たいときは、まず `合計` と各領域の file count / 概算使用量を見る
- 添付や原本が増えている疑いがある場合は `storage/document_files`、build artifact が増えている疑いがある場合は `storage/docs_sites`、dry-run や import staging が残っている疑いがある場合は `storage/imports` を見る
- `大きい内訳` は上位 5 件だけの direct child preview として読み、行ごとの file count、概算使用量、最終更新から増加元の当たりを付ける。続きの全件一覧や削除判断を提供するものではない
- `Docs site build` の内訳は project code / document slug / site directory 相当の直下項目を読むための入口で、Docusaurus build artifact の詳しい前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) に戻る
- `Import staging` の内訳は import run / upload root / staging directory 相当の直下項目を読むための入口で、manual upload dry-run や ZIP import の文脈は既存画面へ戻って確認する
- `DocumentFile 実体の Project / Document 上位` では、容量増加の当たりを付けたい Project / Document を上位 5 件だけ確認する。大きい行があっても、その場で削除対象や retention 対象とは断定しない
- `実体欠落` が 0 でない行は、容量 breakdown だけで完結させず、`欠落ファイル詳細` で対象の `Storage key` / safe `Expected path` preview を確認する
- `DocumentFile 実体` の `次の確認先` は、登録済み file の実体欠落を調べる `欠落ファイル詳細` と、保存先・配信・cleanup 境界を読み直す [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
- `Docs site build` の `次の確認先` は、Docusaurus build workspace や Kroki runtime、site artifact の前提を確認する [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md)
- `Import staging` の `次の確認先` は、manual upload dry-run の既存確認画面と ZIP import の既存入口。どちらも staging artifact の読み方に戻るための導線であり、古い artifact をその場で削除する操作ではない
- `次の確認先` に `この行は read-only 集計です` と出る行は、確認先の設定漏れではなく、その行自体を read-only な概算確認で止める合図として読む
- `文書ファイル健全性` は登録済み `DocumentFile` の実体欠落を確認する入口で、`Storage使用量` は local storage 領域別の容量と DocumentFile 実体の上位 preview を確認する入口として分ける
- 欠落ファイルの実体調査は `欠落ファイル詳細`、容量や保存先方針の確認は [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md) へ戻る

注意点:

- `Storage使用量` は read-only であり、削除、archive、cleanup、retention policy 決定、GCS API 連携は行わない
- 大きい値が出ても、その画面だけで不要ファイルや削除対象を断定しない
- Project / Document breakdown は `DocumentFile` 実体だけの上位 preview であり、`storage/docs_sites` / `storage/imports` は direct child preview に留める。外部 bucket、customer 単位の課金・容量レポート、Project / Document 別の build/import 容量集計を追加したものではない
- 外部 object storage の bucket 使用量、signed URL、public access policy、Project / Document 単位の課金・容量レポートは current support 外として扱う
- alert rule や通知 channel は current repo では具体実装ではない。監視観点は [監視・アラート設計](./監視・アラート設計.md) に戻す

## 日常確認ポイント

- model 数や最終更新に急な変化がないか
- model browser index の group 見出しで、近い領域の model がまとめて確認できているか
- `モデル検索` と `代表フィールド検索` を使い分け、catalog entry を探すのか最近の record sample を絞るのかを混同していないか
- index 検索から detail に入った場合、`モデル一覧へ戻る` が検索済み index へ戻る導線であり、detail 内の `代表フィールド検索` とは別文脈だと分けて読めているか
- `既存画面で詳しく確認` が検索語を引き継ぐ場合と、コピーして既存画面で再確認する場合を混同していないか
- `警告` `エラー` が、sample 値の流用なのか実運用に影響する不足なのか
- `アプリ設定診断` の status / category filter が表示行だけを絞るもので、filter 0 件を診断全体 healthy と読み替えていないか
- 欠落ファイルが単発なのか、storage 全体の問題に見えるのか
- 欠落ファイル詳細の案件 filter が案件コード / 案件名で候補を探す remote search であり、候補上限外の selected project も復元される前提で読めているか
- 欠落ファイル詳細の `条件をクリア` が、有効な案件 / 文書 / ファイル filter があるときだけ出る状態解除導線だと読めているか
- `Storage key` と `Expected path` preview の役割を分け、raw absolute path が通常 UI に出ない前提で切り分けているか
- `Storage使用量` が local directory の概算容量として読めており、`大きい内訳` と `DocumentFile 実体の Project / Document 上位` を削除や retention 判断の実行入口と混同していないか
- `運用失敗入口` では `保存済み履歴` と `継続失敗候補` を分け、保存済み failed 件数と最新 run の連続失敗候補を混同していないか
- `古い失敗のみ` が出ている場合、7 日より古い対象履歴だけが残っている cue として読み、緊急度、通知状態、ack 状態の判断材料にしない
- dashboard だけで完結させず、必要な既存管理画面や仕様 docs にすぐ戻れているか

## 迷ったときの切り分け

- まず全体の変化や異常の有無を見たい: `ダッシュボード`
- 特定 model の件数や最近の record を見たい: `モデルブラウザ`
- 近い領域の model をまとめて確認したい: `モデルブラウザ` index の group 見出し
- model browser に載っている対象 model を探したい: `モデルブラウザ` index の `モデル検索`
- model browser index で検索結果が 0 件になる: record 名や public_id ではなく、model 名、key、説明、group の表記を変えて探す
- 検索済みの model 一覧から detail に入って戻りたい: detail の `モデル一覧へ戻る` または breadcrumb で元の検索済み index へ戻る
- model 詳細内の最近の record sample から識別値を探したい: `モデルブラウザ` show の `代表フィールド検索`
- detail から既存画面で続けて調べたい: `既存画面で詳しく確認` を使い、検索語引き継ぎの有無に応じて既存画面側で再確認する
- `.env` や compose の設定不足を見たい: `アプリ設定診断`
- `アプリ設定診断` で原因の種類や状態を絞って見たい: status / category filter を使い、全体 summary と表示中件数を分けて確認する
- `アプリ設定診断` の filter 0 件が出ている: 現在条件に一致する行がない状態として読み、`すべて` に戻すか summary で全体の `OK / 警告 / エラー` 件数を確認する
- 運用失敗入口の数値を読み分けたい: `保存済み履歴` は保存済み failed 件数、`継続失敗候補` は同じ identity の最新 run が連続 failed かを見る read-only 調査入口として分ける
- `古い失敗のみ` が出ている: 7 日より古い対象履歴だけが残っている状態として読み、緊急度や通知 / ack 状態は対象 runbook と履歴 detail で別途確認する
- 実体ファイルが見えない原因を切り分けたい: `文書ファイル健全性`
- 欠落ファイル詳細で特定案件だけを見たい: 案件コード / 案件名の remote search で案件を選び、文書名 / slug や Storage key / ファイル名の断片と組み合わせて先頭 100 件の read-only 一覧を絞る
- 欠落ファイル詳細で `条件をクリア` が出ていない: 有効な filter はない状態として読み、空白だけの検索語が残っているとは扱わない
- local storage の領域別使用量を read-only に確認したい: `Storage使用量`
- `Storage使用量` の `DocumentFile 実体の Project / Document 上位` に大きい行がある: 容量増加の当たりを付ける preview として読み、対象文書や保存方針は [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md) と対象文書の詳細で確認する
- `Storage使用量` の `DocumentFile 実体` が増えている: `欠落ファイル詳細` と [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md) で登録済み file と保存方針を確認する
- `Storage使用量` の `Docs site build` が増えている: `大きい内訳` で上位 direct child と最終更新を確認し、[notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) で build artifact と runtime 前提を確認する
- `Storage使用量` の `Import staging` が増えている: `大きい内訳` で上位 direct child と最終更新を確認し、manual upload dry-run や ZIP import の既存入口で staging artifact の文脈を確認する
- storage の保存先、配信、cleanup 境界を見直したい: [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
- 個別のアクセス履歴や利用傾向を追いたい: [監査ログ運用runbook](./監査ログ運用runbook.md) や [文書利用状況運用runbook.md](./文書利用状況運用runbook.md) に戻る

## 関連画面

- `app/controllers/admin/dashboard_controller.rb`
- `app/views/admin/dashboard/index.html.slim`
- `app/controllers/admin/missing_document_files_controller.rb`
- `app/views/admin/missing_document_files/show.html.slim`
- `app/controllers/admin/model_browsers_controller.rb`
- `app/views/admin/model_browsers/index.html.slim`
- `app/views/admin/model_browsers/show.html.slim`
- `app/services/admin/model_browser_catalog.rb`
- `app/services/storage_usage_summary.rb`
- `app/checks/application_configuration_diagnostic.rb`
- `app/checks/document_file_health_check.rb`
