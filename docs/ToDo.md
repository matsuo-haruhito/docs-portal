# ToDo

この文書には、現時点の仕様には含めないが、将来検討・実装する可能性があるものを記載する。

仕様として確定したものは、該当する docs 文書へ移動する。具体 Issue があるものは、この文書に要件を重複して残さず、Issue 番号と正本 docs への導線だけを残す。

各項目を次の 4 種類に分けて扱う。

- **実行可能タスク**: 対象ファイル/画面、変更内容、完了検証条件が揃っており即着手できる
- **具体 Issue あり**: Issue 番号 + 正本 docs リンク + 判断論点のみ保持
- **人間判断待ち**: 採否、顧客合意、法務・承認・権限・通知などの中核判断が必要
- **未起票（具体情報待ち）**: 具体画面、運用痛点、再現条件、受け入れ条件が固まった時点で concrete issue に切り出す

---

## 権限・管理画面

- 管理画面の未確認 numeric id 導線が見つかった場合は、対象 resource と URL を確認し `spec/routing/admin_route_identifier_contract_spec.rb` の分類と対応 docs をそろえる concrete issue に切る。分類: 未起票（具体情報待ち）
- 正式なレビュー・承認ワークフロー導入は、コメント・品質チェック・公開制御・送付運用が固まってから再評価する。分類: 人間判断待ち
- 最小確認依頼 / OK・Cancel 機能 — #3418 + #3421。正本: [利用者向け確認依頼runbook](./runbooks/viewer/利用者向け確認依頼runbook.md)。判断論点: 状態名・通知・SLA・段階承認は先取りしない範囲の画定。分類: 具体 Issue あり

## UI / UX

- 実画面への gem 展開計画 → [ROADMAP.md](../ROADMAP.md) を参照。分類: 未起票（具体情報待ち）
- 社内 / 社外 / 管理者ごとの導線差分は、対象画面・導線差分・受け入れ条件が画面群ごとに固まった時点で個別 issue に切る。分類: 未起票（具体情報待ち）
- 総合 UI/UX 見直しは包括 issue として残さず、必要になった時点で具体 issue に分ける。分類: 未起票（具体情報待ち）
- 本文表示の改善は viewer 単位の issue を優先し、再現条件付きで起票する。分類: 未起票（具体情報待ち）

### UI / UX 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 起票候補 | viewer / dashboard / admin の role 別導線差分を画面群ごとに棚卸しする | `track:docs` / `track:design` | dashboard、文書詳細、admin landing のいずれか 1 画面群 | [ダッシュボードと文書ショートカット・確認依頼の使い分け](./specs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md)。起票時は 1 画面群に閉じる |
| 起票候補 | viewer 本文表示の読みづらさを 1 surface で再現条件付きにする | `track:design` / `track:docs` | 文書詳細または版詳細 preview の 1 surface | [版詳細プレビュー・差分・添付確認runbook](./runbooks/viewer/版詳細プレビュー・差分・添付確認runbook.md)。再現条件がない間は実装 queue に戻さない |
| human decision | 全画面 UI/UX redesign、global navigation 再設計、role model 変更 | `track:design` | 全画面横断 | 仕様採否、role / 権限、導線優先順位の判断が必要 |
| 具体情報待ち | 社内 / 社外 / 管理者の導線差分全般 | `track:docs` | 画面未特定 | 対象画面、期待する導線差、受け入れ条件が揃ったら concrete issue に切る |

分類: 未起票（具体情報待ち）

## public_id / URL

- 未確認の numeric id 導線が見つかった場合は、対象 resource と URL を確認できた時点で個別 issue に切る。分類: 未起票（具体情報待ち）

## latest_version / バージョン管理

- `latest_version` の明示指定 — #1112。正本: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)。判断論点: 手動切り替えの権限・監査・UI 要件。分類: 具体 Issue あり
- 古い DocumentVersion の削除・archive・retention policy は不可逆操作の承認要件を分けて判断する。分類: 人間判断待ち
- importer と手動アップロードの latest version 切り替え統一 — #758。正本: [importと変更系dry-run](./specs/importと変更系dry-run.md)。判断論点: 手動アップロード契約と importer の差分統一方針。分類: 具体 Issue あり

## archived / 復元

- bulk archive / bulk restore の read-only 引き継ぎ — #3268。正本: [文書マスタ運用runbook](./runbooks/admin/文書マスタ運用runbook.md)。判断論点: 候補表示を実行可能にするか read-only に留めるか。分類: 具体 Issue あり
- discard candidate marking、自動通知、自動削除、非可逆 discard は retention policy・通知先・復元期限・承認要件を分けて判断する。分類: 人間判断待ち

## Import / GitHub Actions

- `latest_version` の別ルール更新 — #1112。正本: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)。判断論点: 現行 created_at 基準との差分。分類: 具体 Issue あり
- manual upload dry-run 後続 — #1604 / #1613 / #1614 / #2224。正本: [internal upload API dry-run・apply運用runbook](./runbooks/import/internal%20upload%20API%20dry-run・apply運用runbook.md)。判断論点: 各 slice の粒度と優先順位。分類: 具体 Issue あり

## Docusaurus / seed

- 検索 ranking、全文検索 index、server-side search、table 内検索との統合は具体的な痛点が出た時点で別 issue に分ける。分類: 未起票（具体情報待ち）

## Data Classification

- `data_classification_tags` を current 実装として扱うか future/proposal へ戻すか — #1246。正本: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)。判断論点: 分類タグの contract 確定。分類: 人間判断待ち
- DocumentVersion / DocumentFile / DocumentSet / Catalog 単位への拡張は #1246 完了後に 1 model の concrete issue で扱う。分類: 具体 Issue あり（dependency wait）
- DLP / 法務判定 / 承認 workflow / 既存文書の一括分類移行は外部合意が必要。分類: 人間判断待ち

## 多言語 / localization

- 多言語文書の feature queue — #1162。正本: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)。判断論点: Document 単位の language と翻訳 relation の first slice 範囲。分類: 具体 Issue あり
- DocumentVersion 単位の language、版ごとの翻訳差分管理、検索 index 多言語最適化、機械翻訳、Docusaurus i18n 全面移行は first slice 後に必要性が具体化した時点で別 issue に分ける。分類: 未起票（具体情報待ち）

## Job / 運用自動化

- 長時間処理の自動リトライは対象処理ごとに冪等性・二重実行・再試行上限が固まってから判断する。分類: 人間判断待ち
- import / build の job 化の retry / replay / scheduler / notification / SLA / queue backend の採否判断。分類: 人間判断待ち
- mail / webhook の job 化は送信機能本体と delivery 契約が固まってから。分類: 未起票（具体情報待ち）
- 生成ファイル run の再実行履歴と retry metadata — #3269。正本: [生成ファイル再試行と定期ジョブ管理 runbook](./runbooks/ops/生成ファイル再試行と定期ジョブ管理runbook.md)。判断論点: 統合履歴への拡張範囲。分類: 具体 Issue あり

### Job / 運用自動化 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 具体 Issue あり | search index rebuild 1 surface の履歴境界棚卸し — #4761 | `track:docs` / `track:quality` | search index rebuild | [search index rebuild 履歴境界メモ](./specs/search-index-rebuild履歴境界メモ.md)。保存候補 metadata は同メモを正本にする |
| human decision | 長時間処理の自動リトライ、通知、SLA、retry policy の採用判断 | `track:ops` / `track:quality` | import / build / mail / webhook 横断 | 冪等性、二重実行、再試行上限、通知先、SLA 判断が必要 |
| 具体情報待ち | mail / webhook job 化 | `track:ops` | mail delivery / webhook delivery | 送信機能本体、delivery 契約が固まった後に 1 surface で切る |

## 品質・運用改善の扱い

- broad umbrella issue は維持せず、再現した問題や具体的な改善対象ごとに起票する。分類: 未起票（具体情報待ち）
- 追加対応が必要になった時は次のように concrete issue に分ける:
  - failing or flaky spec の修正
  - import/build/mail/webhook の個別 job 化と履歴
  - specific N+1 / slow query / index 追加
  - migration safety / constraint 追加
  - viewer / build / Kroki / npm version pin の個別修正
  - structured logging / error reporting / admin failure inspection の個別導線

### 品質・運用改善 未起票候補の棚卸し

| 分類 | 候補 issue title | 主 track | 対象画面または route | 根拠 docs / 起票しない理由 |
| --- | --- | --- | --- | --- |
| 起票候補 | failing / flaky spec を 1 spec file と再現ログに閉じて修正する | `track:quality` | 再現した spec file または CI job | [テスト方針](./テスト方針.md)。spec 名、失敗ログ、期待挙動が揃った時点で切る |
| 具体 Issue あり | docs index / runbook 掲載漏れ検出 — #2766 | `track:docs` / `track:quality` | `docs/README.md`、`docs/**/*runbook*.md` | 対象集合と allowlist が固まったら #2766 に戻す |
| 具体 Issue あり | ApplicationConfigurationDiagnostic と本番 health check docs の drift — #4486 | `track:docs` / `track:quality` | `docs/specs/本番運用・インフラ前提.md`、`docs/specs/監視・アラート設計.md` | diagnostic 実装や alert rule 追加へ広げない |
| human decision | observability / error reporting / alert rule / 通知 channel の採用判断 | `track:ops` / `track:quality` | 監視 / alert / external service 横断 | 外部監視サービス、通知先、SLA、運用責任分界の判断が必要 |
| 具体情報待ち | performance / DB integrity / migration safety の個別改善 | `track:quality` | slow query、constraint、migration path のいずれか 1 対象 | 観測指標、対象 model / query / migration、受け入れ条件が揃った時点で切る |

## 依存 gem の導入方針

- internal UI gem の release train → [release-train-current-queue](./internal-ui-gem/release-train-current-queue.md) を正本にする。`rails_fields_kit` pinned ref 更新は #1300。分類: 具体 Issue あり
- 実画面への gem 展開計画 → [ROADMAP.md](../ROADMAP.md) を参照。分類: 未起票（具体情報待ち）
- 新しい gem を入れる時は、Rails 標準で代替できない理由・運用コスト・導入範囲を記録する。concrete use-case が出るまで採否判断しない。分類: 未起票（具体情報待ち）

## テスト

- latest_version の created_at 基準と override 方針 — #1112。正本: [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md)。判断論点: ルール変更時のテスト受け入れ条件。分類: 具体 Issue あり
