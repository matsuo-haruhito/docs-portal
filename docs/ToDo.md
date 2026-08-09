# ToDo

この文書には、現時点の仕様には含めないが、将来検討・実装する可能性があるものだけを記載する。

- ここに書くもの: 将来の検討事項、人間判断待ち、未起票の要望、open な具体 Issue への導線
- ここに書かないもの: 実装済み・close 済みの項目、現在仕様、完了履歴、gem 展開や Stimulus 化などの短期アクション
- 仕様として確定したものは該当する正本 docs へ移し、完了履歴は git / GitHub で参照する
- 具体 Issue があるものは、この文書に要件を重複して残さず、Issue 番号、正本 docs、残る判断論点だけを残す
- 未起票のまま残す項目は、まだ起票しない理由を短く添える

項目は次の 3 種類で扱う。

- **具体 Issue あり**: ToDo 側では Issue 番号、正本 docs、残る判断論点だけを残し、実装詳細は Issue と正本へ寄せる
- **人間判断待ち**: 採否、顧客合意、法務、承認、権限、通知、不可逆操作などの中核判断が必要
- **未起票のまま残すもの**: 具体画面、運用痛点、再現条件、または受け入れ条件が固まった時点で concrete issue に切り出す

open な具体 Issue がなくなった項目はこの文書から削除する。close 済み Issue を進行中キューとして残さない。

---

## 権限・管理画面

- 管理画面の未確認 numeric id 導線: 分類は未起票のまま残すもの。対象 resource と URL が特定できた時点で、route、controller lookup、view link、routing spec を 1 件の issue に閉じる。まだ起票しない理由は、対象導線が未特定のため。
- 正式なレビュー・承認 workflow: 分類は人間判断待ち。法務・顧客承認、承認者 chain、通知、差し戻し、SLA の採否が必要。現在の確認依頼、コメント、品質チェックを正式承認済みの意味へ拡張しない。
- access request の `manage` 自動承認: 分類は人間判断待ち。現在は申請記録・検索・却下だけを許可し、権限は管理者が権限管理画面で直接設定する。自動承認を導入する場合は、付与対象、監査、取消、権限昇格の承認要件を先に決める。

## UI / UX

- 社内 / 社外 / 管理者ごとの導線差分: 分類は未起票のまま残すもの。まだ起票しない理由は、対象画面、導線差分、受け入れ条件が画面群ごとに固まっていないため。起票時は dashboard、viewer、admin landing のいずれか 1 画面群に閉じる。
- 総合 UI/UX 見直し: 分類は未起票のまま残すもの。まだ起票しない理由は、broad umbrella では review と acceptance が大きすぎるため。具体的な操作上の痛点と対象 surface が確認できたときに個別 issue に分ける。
- viewer 本文表示の改善: 分類は未起票のまま残すもの。まだ起票しない理由は、再現条件が未特定のため。文書詳細または版詳細 preview の 1 surface と viewport を固定して起票する。

短期の gem 展開、Stimulus 化、UI 基盤の候補は [ROADMAP](../ROADMAP.md) を正本にする。

## latest_version / 版管理 / retention

- 古い `DocumentVersion` の削除、archive、retention policy: 分類は人間判断待ち。不可逆操作の承認要件、保管期間、監査、復元可否を分けて決める。
- bulk archive / bulk restore の実行機能: 分類は人間判断待ち。現在の read-only 候補引き継ぎを変更操作へ広げる場合は、dry-run、上限、権限、maintenance mode、部分失敗の扱いを先に決める。
- discard candidate の自動通知、自動 archive、自動削除、非可逆 discard: 分類は人間判断待ち。現在のレビュー記録は候補日を変更せず、削除や archive を自動実行しない。

## Import / Git / build

- Git 側削除候補の自動 archive / delete: 分類は人間判断待ち。現在は同期結果に候補を残すだけで、外部側の削除を portal の不可逆操作へ直結させない。
- Git Webhook 自動同期・高頻度定期同期: 分類は人間判断待ち。冪等性、同一 commit の重複処理、認証、rate limit、失敗履歴、再実行方針を決めてから 1 surface で起票する。
- import / build の retry、replay、scheduler、notification、SLA、queue backend: 分類は人間判断待ち。対象 job ごとに二重実行時の安全性と再試行上限を確定する。

## Docusaurus / 検索

- 検索 ranking、全文検索 index、server-side search、table 内検索との統合: 分類は未起票のまま残すもの。まだ起票しない理由は、具体的な検索失敗例、対象データ量、受け入れ条件が未特定のため。
- Markdown preview table の full `rails_table_preferences` 統合: 分類は未起票のまま残すもの。現在は app 側 preview tool を維持する。まだ起票しない理由は、通常一覧と preview table で共有すべき preference contract が未確定で、現行 fallback に具体的な不足が再現していないため。

## Data Classification

- DocumentVersion / DocumentFile / DocumentSet / Catalog 固有の分類タグ: 分類は未起票のまま残すもの。現在の Document 単位タグと親 Document からの表示・品質 warning を正本とする。まだ起票しない理由は、固有タグが必要な 1 model / 1 surface と受け入れ条件が未特定のため。
- DLP、法務判定、承認 workflow、既存文書の一括分類移行: 分類は人間判断待ち。分類タグを閲覧・download 権限の代替にしない。

## 多言語 / localization

- `DocumentVersion` 単位の language、版ごとの翻訳対応・差分管理: 分類は未起票のまま残すもの。現在の Document 単位 language / translation relation を正本とする。まだ起票しない理由は、版単位の言語管理が必要な具体的利用例と受け入れ条件が未特定のため。
- 検索 index の多言語最適化、コメント翻訳、機械翻訳、自動翻訳生成、Docusaurus i18n 全面移行: 分類は人間判断待ち。対象言語、品質責任、費用、公開承認を先に決める。

## Job / 外部連携

- 長時間処理の自動 retry: 分類は人間判断待ち。Webhook delivery の限定自動再送を他 job の一般契約とはみなさず、対象処理ごとに冪等性、二重実行、再試行上限を決める。
- mail delivery の job 化と自動再送: 分類は未起票のまま残すもの。まだ起票しない理由は、delivery 履歴、冪等キー、受信側重複影響、失敗時運用の契約が未確定のため。
- Webhook 自動再送の指数 backoff、通知、ack / escalation: 分類は人間判断待ち。現在の 5xx / response 未取得・最大3回という限定契約を広げる場合だけ別 issue にする。

## 品質・運用改善

- 安定化を進める broad umbrella issue は原則として維持しない。分類は未起票のまま残すもの。まだ起票しない理由は、再現した問題、対象 job / spec、観測指標、受け入れ条件が揃うまで umbrella では扱えないため。
- failing / flaky spec: spec file、失敗ログ、再現条件、期待挙動が揃った時点で 1 件に閉じて起票する。
- specific N+1 / slow query / index / constraint / migration safety: 対象 model・query・migration、観測値、受け入れ条件が揃った時点で個別 issue にする。
- observability、error reporting、alert rule、通知 channel: 分類は人間判断待ち。外部サービス、通知先、SLA、運用責任分界を決めてから導入する。

## 依存 gem

- internal UI gem の pinned ref 更新は `1 gem = 1 branch = 1 PR` とし、対象 SHA、代表 smoke、rollback target が確定したものだけ concrete issue にする。
- 新しい gem は、Rails 標準で代替できない理由、運用コスト、導入範囲、rollback を記録できる concrete use case が出るまで採用判断しない。
