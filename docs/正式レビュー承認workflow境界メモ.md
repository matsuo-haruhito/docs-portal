# 正式レビュー承認 workflow 境界メモ

このメモは、正式なレビュー・承認 workflow を設計する前に、current support の周辺機能と human decision 待ちの論点を読み分けるための棚卸しです。

新しい workflow state、通知、SLA、担当者割当、多段承認、権限変更、承認 UI はここでは定義しません。current support の正本は各 runbook / spec に置き、このメモは後続 Issue を誤って実装 queue に流さないための入口として扱います。

## 先に見るもの

- [ToDo](./ToDo.md): 正式なレビュー・承認 workflow は再評価待ちの proposal として扱う
- [文書コメント・Q&A運用runbook](./文書コメント・Q&A運用runbook.md): public Q&A と internal-only 確認事項の使い分け
- [版品質チェック runbook](./版品質チェックrunbook.md): 品質チェック結果の read-only evidence
- [利用者向け確認依頼runbook](./利用者向け確認依頼runbook.md): 確認依頼の一覧・detail・OK / Cancel の current flow
- [文書ライフサイクルと公開](./specs/文書ライフサイクルと公開.md): draft / published / archived、公開 window、latest version の正本
- [外部送付履歴運用runbook](./外部送付履歴運用runbook.md): 外部送付の下書き、送付済み、送付失敗の記録確認

## current support の棚卸し

| 領域 | current support | 正式 workflow と混同しない境界 |
| --- | --- | --- |
| 文書コメント / Q&A | public Q&A と internal-only 確認事項を文書・版に紐づけて残せる。Q&A は `受付中` / `回答済み` / `クローズ`、確認事項は internal user が `解決` できる | 通知、SLA、担当者割当、自動エスカレーション、承認 state machine ではない |
| 版品質チェック | internal user が HTML / JSON / Markdown の read-only evidence として warning / error / info を確認できる | 品質判定 policy、ack、saved report、通知、job 化、公開承認の自動 gate ではない |
| 利用者向け確認依頼 | 文書詳細から確認依頼を作成し、一覧・detail で `対応待ち` / `OK済み` / `Cancel済み` を確認できる | Cancel 理由、通知仕様、SLA、多段承認、正式な承認者 chain は current support ではない |
| 公開制御 | DocumentVersion の draft / published / archived、公開 window、latest version、権限判定を個別に確認できる | 承認 workflow の採否、法務判断、顧客合意、公開前承認 route を自動で定義するものではない |
| 外部送付履歴 | 外部送付の下書き、送付済み、送付失敗を記録し、宛先・方式・失敗理由・戻り先を見返せる | メール運用 rule、送付承認、再送 queue、通知済み状態、顧客承認済み status ではない |

## runbook を更新するときの確認観点

関連 runbook を更新するときは、まずその文書が説明している current flow と、future workflow として残す論点を分けます。

- 文書コメント / Q&A: `回答済み`、`クローズ`、確認事項の `解決` は workspace 内の状態読み分けです。期限、担当割当、通知、承認完了条件を足す場合は `needs-human` に戻します。
- 版品質チェック: `pass` / `fail`、warning / error / info は read-only evidence です。公開可否の自動 gate、ack、品質 policy、通知を足す場合は `needs-human` に戻します。
- 利用者向け確認依頼: `対応待ち` / `OK済み` / `Cancel済み` は軽量な確認依頼の current status です。Cancel 理由、承認者 chain、SLA、段階承認を足す場合は `needs-human` に戻します。
- 公開制御: draft / published / archived、公開 window、latest version は公開状態と閲覧可否の contract です。公開前承認 route、法務・顧客承認、権限変更を足す場合は `needs-human` に戻します。
- 外部送付履歴: `送付済み` / `送付失敗` は手元の送付結果を記録した状態です。送付承認、顧客受領確認、通知済み status、再送 queue を足す場合は `needs-human` に戻します。

docs-only PR では、上記の境界をリンクや短い注意書きで揃えるだけに留めます。状態名、権限、通知、DB schema、controller、request spec を変更しないと完了できない場合は、このメモを根拠に停止します。

## 誤読しやすい言葉

| 言葉 | current support での読み方 | human decision 待ちに戻す論点 |
| --- | --- | --- |
| レビュー | internal-only 確認事項、Q&A、品質チェック結果、文書・版の確認作業 | 正式な reviewer role、review assignment、レビュー期限、レビュー完了条件 |
| 確認 | 確認依頼の OK / Cancel、文書や版の手動確認、runbook に沿った read-only evidence 確認 | 確認ポリシー、通知、SLA、段階確認、必須確認者 |
| 承認 | current support では正式承認 workflow として扱わない | 承認 state、承認者 chain、差し戻し、承認なし公開禁止、法務・顧客承認 |
| 送付済み | 外部送付履歴で、手元の送付結果を記録した状態 | 顧客受領確認、契約上の送達完了、送付前承認、送付後 SLA |
| 品質判定 | 品質チェック画面の warning / error / info を読むための evidence | 公開可否の自動判定、承認 gate、品質 policy の確定、通知 / ack |

## 後続 Issue に切るときの目安

- `track:docs` / `risk:low`: 既存 runbook への導線追加、current support の表現整理、proposal 境界の補足だけで完結する
- `track:quality` / `risk:low-medium`: 既存 behavior を request spec や docs-quality で固定する。runtime behavior を変えない
- `track:design` / `risk:medium`: 画面上の cue、文言、入力導線を変えるが、状態遷移や権限は変えない
- `needs-human`: 承認 workflow の採否、状態名、通知、SLA、担当者割当、多段承認、権限変更、法務・顧客合意が必要

## 非目標

- 正式レビュー・承認 workflow の仕様確定
- 新しい DB schema、state machine、route、controller、view、spec の追加
- 通知、SLA、担当者割当、多段承認、差し戻しの設計
- 公開承認や送付承認の policy 決定
- 既存コメント・品質チェック・確認依頼・公開制御・送付履歴の実装修正
