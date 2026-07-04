# docs

このディレクトリは、この repo で運用する仕様・規約・方針の置き場です。

## 最初に読む

1. [Product Profile](../Product%20Profile.md)
2. [アプリケーション仕様](./アプリケーション仕様.md)
3. [テスト方針](./テスト方針.md)
4. [開発・保守ガイド](./開発・保守ガイド.md)
5. タスクに関係する補助仕様や runbook

UI / JavaScript / Vite / Stimulus / 関連 gem を触る場合は、[フロントエンド操作の方針](../doc/frontend_interaction_policy.md) も先に確認してください。実画面への internal UI gem 展開候補は [ROADMAP](../ROADMAP.md) を入口にし、screen-by-screen adoption、release train、representative smoke の読み分けは [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) で確認します。

この index で Issue / PR 番号を含む補助 docs は、current support の証跡、historical evidence、次に見る候補、proposal のいずれかとして読み分けます。番号だけを current action とせず、各 docs の本文、ROADMAP の文脈、current code を合わせて確認してください。

## タスク別入口

- 利用者画面 / viewer: [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md) から入り、文書詳細・版詳細・ZIP・アクセス申請は日常 UI / viewer の runbook を辿ります。
- admin 運用: [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md) を入口にし、アクセス申請、文書マスタ、文書セット、監査ログ、文書利用状況は admin 運用の各 runbook を確認します。
- import / build / sync: [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) と [手動アップロード差異確認runbook](./手動アップロード差異確認runbook.md) から、Git連携、ZIP、internal upload API、外部フォルダ同期へ進みます。
- 外部連携 / preview: [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md) と [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md) を起点に、preview 接続や外部フォルダ同期の境界を確認します。
- 監視 / インフラ: [監視・アラート設計](./監視・アラート設計.md)、[リリース・デプロイ・rollback手順](./リリース・デプロイ・rollback手順.md)、[バックアップ・リストア手順](./バックアップ・リストア手順.md) を先に見ます。
- internal UI gem: [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md)、[関連 gem 採用マトリクス](./関連gem採用マトリクス.md)、[internal UI gem downstream adoption smoke matrix](./internal-ui-gem-downstream-adoption-smoke-matrix.md)、[関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) で upstream evidence、downstream smoke、release train、host app 採用画面の役割を切り分けます。

## 仕様

- [アプリケーション仕様](./アプリケーション仕様.md)
- [基本モデルと権限](./specs/基本モデルと権限.md)
- [閲覧画面とUI](./specs/閲覧画面とUI.md)
- [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)
- [importと変更系dry-run](./specs/importと変更系dry-run.md)
- [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md)
- [Git連携インポート](./Git連携インポート.md)
- [Google Drive外部フォルダ同期](./Google%20Drive外部フォルダ同期.md)
- [利用規約・秘密保持の同意管理](./利用規約・秘密保持の同意管理.md)
- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md)
- [Internal upload API naming](./internal_upload_api_naming.md)
- [Client file upload API flow](./client_file_upload_api.md)
- [Local folder sync client design](./local_folder_sync_client.md)

## UIモック

- [Markdown編集・HTMLプレビュー・版差分ビュワー](./ui-mocks/markdown_preview_diff_viewer.html): 実画面ではなく design reference。current support と proposal の境界は mock 冒頭の注記を先に確認します。

## 開発・運用

- [開発・保守ガイド](./開発・保守ガイド.md)
- [フロントエンド操作の方針](../doc/frontend_interaction_policy.md)
- [フロントエンド初期化 inventory](../doc/frontend_initialization_inventory.md): Vite entrypoint、gem controller、app 側 Stimulus controller、維持する fallback path を挙動変更なしで棚卸しする入口
- [ROADMAP](../ROADMAP.md): internal UI gem の実画面展開候補、一覧画面の `rails_table_preferences` 化、フォームの `rails_fields_kit` 化、`tree_view` 連携強化、Stimulus 化の次フェーズ
- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md): `tree_view` / `rails_table_preferences` / `rails_fields_kit` の representative smoke、upstream evidence、更新順、rollback note を 1 箇所で見る入口
- [internal UI gem table contract first slice](./internal-ui-gem-table-contract-first-slice.md): RFK / RTP / TreeView / docs-portal の representative screen と responsibility boundary を #4271 の first slice として確認する補助メモ
- [internal UI gem downstream adoption smoke matrix](./internal-ui-gem-downstream-adoption-smoke-matrix.md): downstream 採用前に見る upstream known-good、public surface、visual evidence、docs-portal representative smoke を 3 gem 共通列で確認する入口
- [internal UI gem release evidence comment template](./internal-ui-gem-release-evidence-comment-template.md): release train / review follow-up で CI、visual evidence、upstream signal、downstream smoke を分けて PR / Issue comment に残す入口
- [internal UI gem cross-repo queue order](./internal-ui-gem-cross-repo-queue-order.md): `#858` / `#607` / `#789` と upstream open gate を読み分け、docs-only queue で先取りしない境界を確認する補助メモ
- [internal UI gem 責務境界 matrix](./internal-ui-gem責務境界matrix.md): host app 側と upstream gem 側の API / ownership / representative smoke の境界を混ぜないための比較表
- [関連 gem 採用マトリクス](./関連gem採用マトリクス.md): `tree_view` / `rails_table_preferences` / `rails_fields_kit` の host app 採用画面、gem 側責務、host app 側責務を横断で読む入口
- [internal UI gem JS resolver matrix](./internal-ui-gem-js-resolver-matrix.md): package-root import、documented direct entrypoint、Vite resolver の current downstream 境界を確認する入口
- [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md): public export、TypeScript declaration、manifest、package verification signal の責務分担を確認する入口
- [internal UI gem public surface guard playbook](./internal-ui-gem-public-surface-guard-playbook.md): public surface、docs drift guard、package evidence、dependency / security observation を同じ粒度で比較する maintainer playbook
- [internal UI gem state cue inventory](./internal-ui-gem-state-cue-inventory.md): admin UI 上の current / selected / filter などの状態表示 cue を gem 横断で読み合わせる入口
- [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md): `rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の static visual artifact 変更時に残す確認証跡
- [host app visual evidence comment guide](./host-app-visual-evidence-comment.md): docs-portal 本体の小さな UI / copy PR で `実ブラウザ未確認` を残すときの PR / Issue comment 書式
- [internal UI gem browser evidence batch checklist](./internal-ui-gem-browser-evidence-batch-checklist.md): upstream static visual artifact の desktop / narrow viewport evidence を同じ粒度で残す companion checklist
- [internal UI gem visual evidence gallery](./internal-ui-gem-visual-evidence-gallery.md): 代表画面別に upstream evidence と docs-portal 側で残す downstream evidence を探す入口
- [internal UI gem packaging gate runbook](./internal-ui-gem-packaging-gates.md): internal UI gem release train で上流 packaging gate と downstream smoke の境界を確認する入口
- [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md): `#1300` -> `#1301` -> `#789` の current queue、old child issue の historical 扱い、bump 実行前の停止条件を確認する入口
- [internal UI gem release train target matrix](./internal-ui-gem-release-train-target-matrix.md): `#2962` の current pin、first tranche 候補、除外 / 判断待ち PR、代表 downstream smoke、rollback target を確認する current snapshot
- [internal UI gem release train readiness matrix](./internal-ui-gem-release-train-readiness-matrix.md): release train 前に package-root / direct entrypoint / Vite・importmap / public API guard / downstream smoke を同じ粒度で読む入口
- [internal UI gem bump PR checklist](./internal-ui-gem-bump-pr-checklist.md): library 別 pinned ref bump PR の host-app smoke、PR body evidence、rollback note、停止条件を実行直前に確認する入口
- [コーディング規約](./コーディング規約.md)
- [テスト方針](./テスト方針.md)
- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md): `.env.example` を基準にした最短起動手順と optional service の切り替え
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md): ローカルで文書を編集して seed / import / portal 更新まで確認する最小フロー
- [標準 seed サンプルと確認用途](./標準seedサンプルと確認用途.md): repo 標準 showcase、`ai-usecases`、任意 `external_samples` の違いと確認観点
- [任意 external_samples 事前検証 dry-run](./任意external_samples事前検証dry-run.md): 任意サンプルを `db:seed` に渡す前に候補・warning・error を DB 変更なしで確認する入口
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md): preview 接続、同期元設定、SharePoint / OneDrive の metadata 保存 first slice、`.env` の役割分担
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
- [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md): external user の権限外文書・添付・export・配信 payload を点検する入口
- [運用 metadata 情報露出点検チェックリスト](./運用metadata情報露出点検チェックリスト.md): admin / integration 運用画面の raw path、payload、外部サービス識別子、webhook header を社外ユーザー向け権限外露出とは別観点で点検する入口
- [情報露出 smoke evidence 運用メモ](./情報露出smoke%20evidence運用メモ.md): external user exposure smoke と operational metadata exposure smoke の PR / release evidence での使い分けと raw value 非転記境界
- [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md): seed build / manual preview renderer / Kroki / 関連 env の runtime 前提
- [Docusaurus Dependabot review gate](./notes/docusaurus-dependabot-review-gate.md): Docusaurus / npm 系 Dependabot PR の maintainer change、install script、rebase / recreate 判断を CI / visual evidence と分けて確認する入口

## Runbook

### 日常 UI / viewer

- [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md): dashboard 起点の個人導線と internal user 向け確認依頼の役割差
- [文書ショートカット運用runbook](./文書ショートカット運用runbook.md): `お気に入り` `後で読む` `最近見た文書` の見分け方、`解除` 後の戻り方、`案件一覧へ戻る` の使いどころ
- [文書カタログ閲覧runbook](./文書カタログ閲覧runbook.md): 案件内の文書グルーピング入口、catalog / item visibility、一覧 filter の読み方、文書一覧・文書セット・文書ショートカットとの使い分け
- [文書コメント・Q&A運用runbook](./文書コメント・Q%26A運用runbook.md): 文書詳細 / 版詳細の `文書コメント` workspace で Q&A と internal-only の確認事項を使い分ける境界
- [正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md): コメント、版品質チェック、確認依頼、公開制御、外部送付履歴を正式な多段承認 workflow と混同しないための棚卸し
- [利用者向けアクセス申請runbook](./利用者向けアクセス申請runbook.md): dashboard の `保留中の申請` から入る一覧、`対象` `要求権限` `状態` `理由` `承認者`、pending の `取消` の見方
- [外部送付履歴運用runbook](./外部送付履歴運用runbook.md): dashboard の `社内向け導線` から入る `送付履歴` 一覧、detail、`メーラーを開く` / `送付済みにする` / `送付失敗として記録` の見分け方
- [文書一覧の検索・実用フィルタ・ZIP出力 runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md): 案件配下の検索条件、左の文書ツリー絞り込み、実用フィルタ、current-page 選択と検索結果全体選択を含む ZIP 出力の見分け方
- [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md): HTML本文、比較対象版、workspace ナビゲーション、添付・元ファイルの検索 / 分類絞り込み、Markdown table annotation first slice と未対応範囲、品質チェックの見分け方
- [Text Preview Line Anchor Target Cue](./text-preview-line-anchor-target-cue.md): text preview の blue line anchor target cue と yellow search match cue、`aria-current="location"` の読み分けを確認する補助メモ
- [版品質チェック runbook](./版品質チェックrunbook.md): internal user 向けの判定サマリ、Preview warning/error、全 check table、JSON / Markdown read-only export の読み方
- [Markdown table toolbar 運用 runbook](./Markdown%20table%20toolbar%E9%81%8B%E7%94%A8runbook.md): Markdown preview の表内検索、CSV / Markdown copy、表示リセット、`列表示` panel の current support と #475 境界の見分け方
- [ZIPプレビューと個別ダウンロード確認 runbook](./ZIP%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E5%80%8B%E5%88%A5%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E7%A2%BA%E8%AA%8Drunbook.md): ZIP内サマリー、ディレクトリサマリー、フィルタ、個別プレビュー、個別ダウンロードの見分け方
- [AI向けコンテキストexport運用runbook](./AI向けコンテキストexport運用runbook.md): 案件詳細の `AI向けコンテキスト` で compact / full / JSON / Markdown、除外文書、AccessLog を確認する手順
- [利用者向け同意画面・同意履歴runbook](./利用者向け同意画面・同意履歴runbook.md): `同意済み文面・注意事項` と `利用上の注意事項への同意` の見分け方、`確認して同意する` / `同意せず戻る` の current flow

### admin 運用

- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md): `モデル観測` `アプリ設定診断` `文書ファイル健全性` の使い分けと戻り先
- [管理画面 nav 領域見出し運用メモ](./管理画面nav領域見出し運用メモ.md): internal admin 向け nav の `運用` / `基本マスタ` / `文書・権限` / `import / sync` / `外部連携` 見出しと company master admin 境界を確認する短いメモ
- [生成ファイル継続失敗候補runbook](./生成ファイル継続失敗候補runbook.md): 管理ダッシュボードの `運用失敗入口` に出る生成ファイル継続失敗候補の identity、連続失敗数、read-only 調査境界の見分け方
- [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md): `アクセス申請` `同意文面` `案件同意設定` `Webhook` の日常確認ポイントと戻り先
- [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md): `company_master_admin` が使える `会社` / `ユーザー` 管理画面と、案件・文書管理 role ではない境界、`/admin` の `会社・ユーザー管理` landing で role 範囲を確認してから `会社` / `ユーザー` へ進む current flow、internal admin へ戻す判断
- [文書マスタ運用runbook](./文書マスタ運用runbook.md): `admin/documents` の検索・状態確認、保管期限 / 廃棄候補、公開側文書への戻り方、`編集` / `アーカイブ` / `復元` / `削除` の見分け方
- [rails_fields_kit 文書マスタ案件選択 runbook](./rails_fields_kit文書マスタ案件選択runbook.md): `admin/documents` form の `project_id` を RFK helper で確認するときの current support と upstream / host app 境界
- [文書一括編集dry-run運用runbook](./文書一括編集dry-run運用runbook.md): `admin/bulk_edit_dry_runs` の対象選択、事前確認、警告 / エラー、変更前後、実行結果の読み方
- [案件・Git連携・文書セット初回セットアップrunbook](./案件・Git連携・文書セット初回セットアップrunbook.md): `案件` 作成、`Git連携` の最小構成、初回取り込み後の `文書セット` 作成順
- [文書セット運用runbook](./文書セット運用runbook.md): `文書セット` 一覧の `種別` / `公開範囲` filter、列の見方、`固定版` と `最新版を使う` の使い分け、文書 0 件案件の empty state の戻り先
- [文書カタログ閲覧runbook](./文書カタログ閲覧runbook.md): `文書カタログ管理` の新規登録・編集・削除、catalog 基本項目、item 構成、公開側 visibility との責務差
- [案件所属・文書権限運用runbook](./案件所属・文書権限運用runbook.md): `案件所属` の role 管理と、`文書権限` の 0 件開始時 empty state、件数確認、個別付与確認の見分け方
- [監査ログ運用runbook](./監査ログ運用runbook.md): `監査ログ` の絞り込み項目、表示設定、最新 200 件の中でどの列を残して読むか
- [文書利用状況運用runbook](./文書利用状況運用runbook.md): `文書利用状況` の案件単位集計、利用あり/なし、既読確認内訳の project 必須・document slug・最新 200 件上限、関連画面への戻り先
- [CSV条件metadata JSON 運用メモ](./CSV条件metadata_JSON運用メモ.md): 監査ログ / 文書利用状況 / 文書セットの CSV companion metadata JSON と CSV 本体・表示設定の役割差

### import / build / sync

- [手動アップロード差異確認runbook](./手動アップロード差異確認runbook.md): `ファイルをアップロード` panel や TreeView / 文書行への drop 後に開く review flow、`OK` / `NG`、反映後の取り消し導線
- [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md): `定期ジョブ` / `生成ファイルイベント` / `生成ファイル実行履歴` の見分け方と再試行導線
- [生成ファイル実行履歴 preview 境界メモ](./生成ファイル実行履歴preview境界メモ.md): `生成ファイル実行履歴` detail の入力パス / 変更ファイル / 生成パス / メタデータ / エラー preview と mask / truncate 境界を読む補助メモ
- [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md): `docs-site` artifact と workflow run / manifest metadata を将来履歴化する場合の保存候補と、保存しない raw payload の境界を読む補助メモ
- [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md): `test` / `seed-smoke` / `build-docs` の見分け方、manifest 生成、artifact、import API の確認順
- [Git連携設定と同期失敗確認runbook](./Git連携設定と同期失敗確認runbook.md): `Git連携` / `Git同期履歴` で見る項目と手動同期の戻り先
- [Git連携 run 履歴保存境界メモ](./Git連携run履歴保存境界メモ.md): Git連携 run を job 化や履歴保存拡張へ進める前に、current support、保存候補 metadata、保存しない raw payload、site build artifact 履歴との違いを確認する補助メモ
- [ZIPインポートdry-run運用runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md): `ZIPインポート` の入力項目、status、TreeView プレビュー、取り込み前の見直し順
- [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run%E3%83%BBapply%E9%81%8B%E7%94%A8runbook.md): `artifact_imports` / `zip_uploads` / `file_uploads` の dry-run 作成と apply の見分け方
- [API仕様ページとdocs-src更新確認runbook](./API%E4%BB%95%E6%A7%98%E3%83%9A%E3%83%BC%E3%82%B8%E3%81%A8docs-src%E6%9B%B4%E6%96%B0%E7%A2%BA%E8%AA%8Drunbook.md): `API仕様` 管理画面で build 待ちと主要ページの HTML 確認を進めるときの入口

### 外部連携 / preview

- [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md): `Webhook` 設定、通知対象イベント、送信履歴、失敗時の確認順、失敗 delivery の 1 件ずつ手動再送と自動 retry 未実装の境界
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md): `preview利用` 列、重複有効接続の整理、Drive ID、プレビュー用フォルダの見直し順
- [外部フォルダ同期dry-run・apply運用runbook](./外部フォルダ同期dry-run・apply運用runbook.md): provider-aware な入口、`最新安全判定` / `競合・重複警告`、Google Drive の current support、SharePoint / OneDrive の metadata 保存 first slice と未対応の同期本体
- [外部フォルダ同期 webhook ignored event の読み分け](./external-folder-sync-webhook-ignored-events.md): Google Drive 変更通知の `ignored` 理由と coalescing / source unavailable の運用上の読み分け
- [外部フォルダ同期継続失敗候補runbook](./外部フォルダ同期継続失敗候補runbook.md): 管理ダッシュボードの `運用失敗入口` に出る外部フォルダ同期の継続失敗候補を、通知や自動 retry ではなく read-only handoff として読む入口
- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md): `rails_fields_kit` / `rails_table_preferences` / `tree_view` の upstream 入口と、`admin/document_sets` を代表例にした host app cookbook。`ROADMAP` の実画面展開候補、`#607` の screen-by-screen adoption、`#858` 系の release train、`#1333` のような実装済み画面の smoke 固定を読み分ける

### 運用・インフラ

- [リリース・デプロイ・rollback手順](./リリース・デプロイ・rollback手順.md)
- [バックアップ・リストア手順](./バックアップ・リストア手順.md)
- [本番運用・インフラ前提](./本番運用・インフラ前提.md)
- [監視・アラート設計](./監視・アラート設計.md): alert 後に最初に見る runbook guidance と監視方針の入口。通知 channel / alert rule / 監視サービス連携は current repo では未実装の境界として読む
- [生成ファイル継続失敗候補runbook](./生成ファイル継続失敗候補runbook.md): dashboard の生成ファイル card に出る継続失敗候補を、通知や自動 retry ではなく read-only 調査入口として読む

## 未確定事項

- [ToDo](./ToDo.md)

## 仕様概要

1. 識別子
   - DB id
   - public_id
   - code / slug
   - URL に出す ID

2. アクセス制御
   - internal user (`User#admin?` / admin surface)
   - company_master_admin user (自社 `会社` / `ユーザー` 管理のみ)
   - external user
   - project membership
   - document permission
   - view/download

3. ドキュメント公開モデル
   - Document
   - DocumentVersion
   - DocumentFile
   - draft / published / archived
   - latest_version
   - バージョン管理あり / なし

4. Docusaurus 表示
   - build 成果物
   - site_build_path
   - rendered_site_available?
   - assets の扱い

5. 添付ファイル
   - Markdown は生ファイル表示
   - download 権限
   - content type / charset

6. Import
   - publish.json
   - version immutability
   - storage_key
   - build artifact
   - Git連携 import source / run
   - ZIP import dry-run / 実行
   - 外部フォルダ同期 source / run / item
   - file_uploads / zip_uploads / artifact_imports の internal API

7. AccessLog
   - 記録対象
   - 記録しない対象
   - last_login_at は users 側で管理

8. 外部連携
   - Webhook endpoint
   - 通知対象イベント
   - 署名付き JSON POST
   - 送信履歴
   - Google Drive外部フォルダ同期

9. 将来対応
   - 現時点の仕様に含めないものは [ToDo](./ToDo.md) に記載する