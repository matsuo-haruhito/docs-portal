# ToDo

この文書には、現時点の仕様には含めないが、将来検討・実装する可能性があるものを記載する。

仕様として確定したものは、該当する docs 文書へ移動する。具体 Issue があるものは、この文書に要件を重複して残さず、Issue 番号と正本 docs への導線だけを残す。

未起票のまま残す項目は、まだ起票しない理由を短く添える。実装痛点、運用要件、顧客確認、または対象画面が具体化した時点で、1 つの concrete issue に切り出す。

この文書を読むときは、各項目を次の 4 種類に分けて扱う。

- 具体 Issue があるもの: ToDo 側では Issue 番号、正本 docs、残る判断論点だけを残し、要件を二重管理しない
- 正本 docs へ移動済みのもの: current behavior は該当 runbook / spec を正本にし、ToDo には未解決の後続判断だけを残す
- 人間判断待ちのもの: 採否、顧客合意、法務・承認・権限・通知などの中核判断が必要な proposal として扱い、実装 queue に戻さない
- 未起票のまま残すもの: 具体画面、運用痛点、再現条件、または受け入れ条件が固まった時点で concrete issue に切り出す

2026-06-24 の first slice では、既に正本 docs / Issue へ移動済みの項目と、人間判断待ち・未起票のまま残す項目が混在しやすい節だけを棚卸しした。ToDo 全体の方針や product strategy は変更せず、各項目の分類と再開条件だけを短く補足する。

2026-07-04 の Issue 4572 first slice では、UI / UX、Job / 運用自動化、品質・運用改善の 3 節だけを追加棚卸しした。ここでの「起票候補」は、そのまま実装着手する指示ではなく、Workflow Manager / Planner が次に concrete issue へ切れる粒度のメモとして扱う。法務、承認、通知、SLA、不可逆削除、外部合意が必要なものは human decision のまま残し、`status:ready-for-agent` に戻さない。

## 権限・管理画面

- `company_master_admin` の current `/admin` redirect と `会社` / `ユーザー` 管理の制約は [company_master_admin会社・ユーザー管理runbook](./company_master_admin会社・ユーザー管理runbook.md) を正本とし、ここには未解決の導線改善だけを残す。分類: 正本 docs へ移動済み
- 管理画面の主要 member route は current `config/routes.rb` と `spec/routing/admin_route_identifier_contract_spec.rb` で `public_id` / `code` の URL 識別子 contract を固定している。主要 admin member resource は `param: :public_id`、`admin/projects` と project member action controller は `param: :code`、collection-only resource は member identifier guard の対象外として分類済み。新しい admin member route や未確認の numeric id 導線を見つけた場合は、対象 resource と URL を確認し、同 spec の分類と対応 docs をそろえる concrete issue に切る。分類: 正本 docs へ移動済み / 未確認 route が出たら concrete issue
- 正式なレビュー・承認ワークフローを導入するかは、コメント・品質チェック・公開制御・送付運用が固まってから再評価する。current support は [文書コメント・Q&A運用runbook](./文書コメント・Q&A運用runbook.md)、[版品質チェック runbook](./版品質チェックrunbook.md)、[利用者向け確認依頼runbook](./利用者向け確認依頼runbook.md)、[文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)、[外部送付履歴運用runbook](./外部送付履歴運用runbook.md) の個別導線として読み、これらを多段承認、通知、SLA、権限変更、公開承認 state machine の実装済み workflow として扱わない。分類: 人間判断待ち。未起票で残す理由: ワークフロー仕様の正誤判断、通知・SLA・承認権限の外部合意が必要
- 形式的な workflow とは別に扱う最小確認依頼 / OK・Cancel 機能は、runtime / UI / spec の first slice を #3418、merge 後の利用者向け runbook 追従を #3421 で扱う。正式なレビュー・承認ワークフローとは分け、状態名・通知・SLA・段階承認は current support として先取りしない。分類: 具体 Issue あり

## UI / UX

- dashboard / navbar / viewer shell / admin model browser の基礎導線は実装済み
- dashboard の internal user 向け確認依頼導線は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md) を正本にする。#1072 の重複感整理は completed のため、ここには追加で必要になった dashboard UX 論点だけを残す。分類: 正本 docs へ移動済み
- 文書利用状況の絞り込み 0 件時 empty state と表示設定 editor の優先度整理は #1077 で completed。current 運用は [文書利用状況運用runbook](./文書利用状況運用runbook.md) を正本にする。分類: 正本 docs へ移動済み
- 社内 / 社外 / 管理者ごとの導線差分は、必要になったタイミングで画面群ごとに個別 issue へ分けて扱う。分類: 未起票のまま残すもの。まだ起票しない理由: 対象画面、導線差分、受け入れ条件が画面群ごとに固まっていない
- 総合 UI/UX 見直しは包括 issue として残さず、必要になった時点で viewer / dashboard / navigation / admin UX など具体 issue に分けて扱う。分類: 未起票のまま残すもの。まだ起票しない理由: broad umbrella では review / acceptance が大きすぎる
- 本文表示の改善は viewer 単位の issue を優先し、全画面の大規模 redesign は後回しにする。分類: 未起票のまま残すもの。まだ起票しない理由: 具体 viewer surface と読みづらさの再現条件が必要

### UI / UX 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 起票候補 | viewer / dashboard / admin の role 別導線差分を画面群ごとに棚卸しする | `track:docs` / `track:design` | dashboard、文書詳細、admin landing のいずれか 1 画面群 | [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md)、[管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)。起票時は 1 画面群に閉じる |
| 起票候補 | viewer 本文表示の読みづらさを 1 surface で再現条件付きにする | `track:design` / `track:docs` | 文書詳細または版詳細 preview の 1 surface | [版詳細プレビュー・差分・添付確認runbook](./版詳細プレビュー・差分・添付確認runbook.md)、[閲覧画面とUI](./specs/閲覧画面とUI.md)。再現条件がない間は実装 queue に戻さない |
| human decision | 全画面 UI/UX redesign、global navigation 再設計、role model 変更 | `track:design` | 全画面横断 | 仕様採否、role / 権限、導線優先順位の判断が必要。broad umbrella として ready 化しない |
| 具体情報待ち | 社内 / 社外 / 管理者の導線差分全般 | `track:docs` | 画面未特定 | 対象画面、現在の迷い、期待する導線差、受け入れ条件が揃ったら concrete issue に切る |

## public_id / URL

- 公開側の主要 route は `code` / `slug` / `public_id` へ移行済み。管理画面の主要 member route も `spec/routing/admin_route_identifier_contract_spec.rb` で `public_id` / `code` を guard しているため、広い route 移行メモとしては残さない。未確認の numeric id 導線が見つかった場合は、対象 resource と URL を確認できた時点で個別 issue に切る。分類: 正本 docs へ移動済み / 未確認 route が出たら concrete issue

## latest_version / バージョン管理

- `version_label` は semantic version として解釈・sort せず、任意の表示用ラベルとして扱う。`2026-Q2` / `review-2026-05` / `client-a-draft` のような label を importer から受けても opaque label として保存する current contract は #1050 で整理済み。sort や latest 判定の扱いを変える場合は #1112 または別の具体 Issue に切る。分類: 正本 docs へ移動済み / 仕様変更時は concrete issue
- `latest_version` は current では published version の作成・更新時に promoted される。管理画面/API/import manifest で明示指定できるようにするかは `#1112` で扱う。ToDo 側では手動切り替えの権限・監査・UI 要件を #1112 の判断論点として参照する。分類: 具体 Issue あり
- 古い DocumentVersion の read-only な整理候補表示と読み方は #2344 と [文書マスタ運用runbook](./文書マスタ運用runbook.md) を正本にする。削除・archive・latest 切り替え・retention policy の最終判断は current support として扱わず、必要になった時点で復元要件や不可逆操作の承認要件を分けて concrete issue に切る。分類: 正本 docs へ移動済み / irreversible operation は人間判断待ち
- importer は latest version 上書き、手動アップロードは `manual-*` draft 候補を追加して review で `latest_version` を切り替える current 差分を、どこまで統一するか再判断する。手動アップロード契約の first slice は `#758` で扱う。分類: 具体 Issue あり

## archived / 復元

- Document 単位 archive / restore は admin 管理画面で実装済み
- 保管期限 / 廃棄候補の current 文書マスタ filter・一覧列・期限間近 filter・手動 archive / restore 判断は [文書マスタ運用runbook](./文書マスタ運用runbook.md) を正本にする。#1054 の first slice は completed のため、ここには current support 外の後続判断だけを残す。分類: 正本 docs へ移動済み
- bulk archive / bulk restore 候補を実行ではなく read-only に引き継ぐ first slice は #3268 で扱う。ToDo 側には候補要件を重複して残さず、正本 docs と #3268 の判断論点だけを参照する。分類: 具体 Issue あり
- discard candidate marking、自動通知、自動削除、非可逆 discard、期限間近 filter より先の alert / workflow 化は後続判断として残す。分類: 人間判断待ち / 未起票のまま残すもの。未起票で残す理由: retention policy、通知先、復元期限、不可逆操作の承認要件を分けて判断する必要がある

## Import / GitHub Actions

- current の manifest 生成手順と `build-docs` workflow の確認順は [build-docs workflow確認runbook](./build-docs%20workflow確認runbook.md) を正本とし、ここでは未完了論点だけを残す。分類: 正本 docs へ移動済み
- artifact の永続保存方式と再取り込み replay 方針の first slice は #1039 で completed。後続で実装する場合は、保存期間・アクセス制御・replay 対象の確定範囲を個別 issue に切る。分類: 正本 docs へ移動済み / 後続は concrete issue
- `latest_version` の明示切り替えや別ルール更新を入れる場合は、現行の created_at 基準との差分を `#1112` の latest_version 明示切り替え contract と合わせて扱う。分類: 具体 Issue あり
- `artifact_imports` / `zip_uploads` / `file_uploads` の dry-run 作成と apply の見分け方は [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md) を正本にする。manual upload dry-run の管理画面確認が変わった場合は #1607 の docs sync で追従する。分類: 正本 docs へ移動済み
- manual upload dry-run の後続判断は、広い確認導線 issue #1604 を再利用して要件を重複させず、raw `source_path` 表示は #1613、後から探せる一覧入口は #1614、詳細画面から internal upload runbook へ戻る導線は #2224 のように concrete issue で扱う。#1607 の docs sync は completed のため、ToDo には runbook 要件を重複して残さない。分類: 具体 Issue あり

## Docusaurus / seed

- seed 用 Docusaurus build で id front matter を自動付与する処理の安定化は #1040 で completed。current runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) を正本にする。分類: 正本 docs へ移動済み
- seed 用 Markdown build 失敗時のログ改善は #1022 / PR #1036 で completed。current runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) を正本にする。分類: 正本 docs へ移動済み
- embedded viewer 前提の iframe 高さ追従 first slice は #1020 で completed。Markdown preview iframe 内の `文書内検索 /` は [版詳細プレビュー・差分・添付確認runbook](./版詳細プレビュー・差分・添付確認runbook.md) を正本にし、検索 ranking、全文検索 index、server-side search、table 内検索との統合は、具体的な痛点が出た時点で別 issue に分ける。分類: 正本 docs へ移動済み / 後続は具体 issue

## Data Classification

- `visibility_policy` と分類タグ候補の責務境界は [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md) を入口にする。ただし `data_classification_tags` を current 実装として扱うか future/proposal 表現へ戻すかは #1246 の人間判断待ちであり、ToDo 側では正誤を断定しない。分類: 人間判断待ち
- DocumentVersion / DocumentFile / DocumentSet / Catalog 単位へ広げる後続論点は、#1246 で親 Document の分類タグ contract が整理された後に、1 model または 1 screen/surface の concrete issue として扱う。分類: 具体 Issue 依存 / dependency wait
- 分類タグは権限判定や公開可否ではなく取り扱い補助として扱う方針候補に留める。DLP / 法務判定 / 承認 workflow / 既存文書の一括分類移行は、外部合意や中核仕様判断が必要になった時点で別 issue に切る。分類: 人間判断待ち

## 多言語 / localization

- 多言語文書の current first slice 方針は [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md) の「多言語文書」節を正本にする。分類: 正本 docs へ移動済み
- 具体的な feature queue は `#1162` で扱う。`Document` 単位の `language` と `Document` 間の manual translation relation、翻訳間で `latest_version` / 公開 window / archive / 権限判定を共有しない境界、閲覧可能な翻訳候補だけを表示する範囲は #1162 で確認する。分類: 具体 Issue あり
- `#1162` と重複しない後続論点だけをここに残す。DocumentVersion 単位の language、版ごとの翻訳差分管理、検索 index 多言語最適化、コメント翻訳、機械翻訳、自動翻訳生成、Docusaurus i18n 全面移行、既存文書一括移行は、first slice 後に必要性が具体化した時点で別 issue に分ける。分類: 未起票のまま残すもの / dependency wait

## Job / 運用自動化

- import / build / mail / webhook の自動リトライ前の冪等性・二重実行リスクは [自動リトライ安全性棚卸し](./自動リトライ安全性棚卸し.md) を正本にする。分類: 正本 docs へ移動済み
- 長時間処理の自動リトライは初期実装で入れない。必要になった場合も、対象処理ごとに separate issue を切り、手動再実行で十分かを先に判断する。分類: 人間判断待ち / 未起票のまま残すもの。まだ起票しない理由: 対象処理ごとの冪等性、二重実行、再試行上限が固まっていない
- import / build の job 化は、`build-docs` 1 workflow の import / build job 化棚卸しを #4738 / PR #4745 と [build-docs import job 化境界メモ](./build-docs-import-job化境界メモ.md) / [build-docs job 化置き換え境界メモ](./build-docs-job化置き換え境界メモ.md) へ移動済みとして扱う。ToDo には retry / replay / scheduler / notification / SLA / queue backend などの採否判断だけを残し、Git連携 run、ZIP import dry-run、internal upload API、search index rebuild は別 surface の concrete issue で扱う。分類: 正本 docs へ移動済み / 人間判断待ち
- mail / webhook の job 化は、送信機能本体と delivery 契約が先に固まってから再評価する。分類: dependency wait
- 生成ファイル run の再実行履歴と retry metadata の current 読み方は #3269 と [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md) を正本にする。Docusaurus site build、検索 index、import / build の統合履歴へ広げる場合は、代表対象と保存境界が具体化した時点で別 issue に切る。分類: 具体 Issue あり / 正本 docs へ移動済み

### Job / 運用自動化 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 正本 docs へ移動済み | build-docs 1 workflow の import / build job 化棚卸しは #4738 / #4745 と正本 docs に移動済み | `track:docs` | `build-docs` workflow | [build-docs import job 化境界メモ](./build-docs-import-job化境界メモ.md)、[build-docs job 化置き換え境界メモ](./build-docs-job化置き換え境界メモ.md)。#4753 は duplicate close 済み。残る retry / replay / scheduler / notification / SLA / queue backend は human decision として扱い、Git連携 run、ZIP import dry-run、internal upload API、search index rebuild へ横展開しない |
| 具体 Issue あり / 正本 docs へ移動済み | search index rebuild 1 surface の履歴境界棚卸しは #4761 と正本メモに移動済み | `track:docs` / `track:quality` | search index rebuild | [search index rebuild 履歴境界メモ](./search-index-rebuild履歴境界メモ.md)。保存候補 metadata と保存しない raw payload は同メモを正本にし、`GeneratedFileRun` / site build artifact / GitImportRun との責務差、retry / replay / scheduler / notification / SLA / queue backend は human decision として扱う |
| human decision | 長時間処理の自動リトライ、通知、SLA、retry policy の採用判断 | `track:ops` / `track:quality` | import / build / mail / webhook 横断 | 冪等性、二重実行、再試行上限、通知先、SLA 判断が必要。実装 queue に戻さない |
| 具体情報待ち | mail / webhook job 化 | `track:ops` | mail delivery / webhook delivery | 送信機能本体、delivery 契約、失敗時の再送 / 通知要件が固まった後に 1 surface で切る |

## 品質・運用改善の扱い

- test / CI / import-build robustness / external dependency stability / performance / DB integrity / observability は、今後も必要に応じて継続改善する
- ただし `安定化を進める` `強化する` のような broad umbrella issue は原則として維持しない
- 追加対応が必要になった時は、次のように concrete issue に分けて扱う。分類: 未起票のまま残すもの。まだ起票しない理由: 再現した問題、対象 job/spec、観測指標、受け入れ条件が揃うまで umbrella では扱わない
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

### 品質・運用改善 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 起票候補 | failing / flaky spec を 1 spec file と再現ログに閉じて修正する | `track:quality` | 再現した spec file または CI job | [テスト方針](./テスト方針.md)、[開発・保守ガイド](./開発・保守ガイド.md)。spec 名、失敗ログ、期待挙動が揃った時点で切る |
| 起票候補 | docs index / runbook 掲載漏れを docs-quality first slice として検出する | `track:docs` / `track:quality` | `README.md`、`docs/README.md`、`docs/**/*runbook*.md`、`docs/specs/*.md` | 分類: 具体 Issue あり。#2766 が既存候補。重複起票せず、対象集合と allowlist が固まったら #2766 に戻す |
| 起票候補 | ApplicationConfigurationDiagnostic と本番 health check docs の drift を守る | `track:docs` / `track:quality` | `docs/本番運用・インフラ前提.md`、`docs/監視・アラート設計.md` | 分類: 具体 Issue あり。#4486 が既存候補。diagnostic 実装や alert rule 追加へ広げない |
| human decision | observability / error reporting / alert rule / 通知 channel の採用判断 | `track:ops` / `track:quality` | 監視 / alert / external service 横断 | 外部監視サービス、通知先、SLA、運用責任分界の判断が必要。docs だけで current support として先取りしない |
| 具体情報待ち | performance / DB integrity / migration safety の個別改善 | `track:quality` | slow query、constraint、migration path のいずれか 1 対象 | 観測指標、対象 model / query / migration、失敗時影響、受け入れ条件が揃った時点で concrete issue に切る |

## 依存 gem の導入方針

- vendor / author 単位の網羅調査 issue は維持しない
- gem 導入は concrete use-case ごとに判断する
  - params 正規化
  - nested form
  - import 補助
  - admin SQL viewer
  - 型生成
- internal UI gem の release train は [internal UI gem release train current queue](./internal-ui-gem-release-train-current-queue.md) を正本にし、`rails_fields_kit` pinned ref 更新は #1300、関連 follow-up は同 docs の queue に沿って扱う。ToDo には upstream API や representative smoke の要件を重複して残さない。分類: 正本 docs へ移動済み / 具体 Issue あり
- 新しい gem を入れる時は、Rails 標準や既存依存で代替できない理由、運用コスト、導入範囲を一緒に記録する。分類: 未起票のまま残すもの。まだ起票しない理由: concrete use-case と導入範囲が出るまで採否判断できない
- 現時点で導入済みの `rparam` / `rtypes` 以外は、必要機能が出たタイミングで個別 issue から判断する

## テスト

- latest_version の created_at 基準と override 方針が変わる場合は、そのルールを `#1112` の受け入れ条件に含めて扱う。分類: 具体 Issue あり
