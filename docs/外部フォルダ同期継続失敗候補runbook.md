# 外部フォルダ同期継続失敗候補 runbook

この runbook は、管理ダッシュボードの `運用失敗入口` に表示される外部フォルダ同期の `継続失敗候補` を読むための補助メモです。

## これは何か

- 外部フォルダ同期 source ごとに、最新 run から `failed` または `partial` が連続しているものだけを read-only に表示します。
- 保存済みの failed / partial 件数とは別の調査入口です。
- 候補 0 件は、外部 provider 全体正常、通知済み、ack 済み、自動 retry 済みを意味しません。

## 候補に出る条件

- identity は `external_folder_sync_source_id` と provider を基本にします。別 source や別 provider の失敗 streak は混ぜません。
- latest run から見て `failed` / `partial` が 3 件以上連続している場合だけ候補になります。
- 後続に `completed` がある古い失敗 streak は候補になりません。
- 管理ダッシュボードでは、最新 200 件の同期 run を見たうえで、候補を最大 5 件だけ表示します。表示外の source が正常、通知済み、ack 済み、自動復旧済みであることは保証しません。

## 画面で見る項目

- 同期設定名
- provider
- project code / project name
- 連続 failed / partial 件数
- 最終失敗時刻
- 短い error preview
- 同期設定詳細への link

error preview は調査の入口だけに使います。token、Authorization header、private-looking path、signed URL 風の値は raw 表示せず、mask / truncate 済みの短い preview として読みます。raw provider error、credential、private path の確認場所ではありません。

## Markdown digest preview の読み方

管理ダッシュボードに `Markdown digest preview` が表示される場合は、候補 list と同じ抽出結果を PR / release / incident handoff に貼りやすくした read-only の要約として扱います。

- digest には source、provider、project、連続 failed / partial 件数、最終失敗時刻、safe error preview、同期設定詳細 path、runbook path が入ります。
- digest の `All error sources` は error 一覧へ戻るための入口であり、全 provider 正常や通知済みを示す証跡ではありません。
- digest の `Runbook` はこの文書の path です。runbook path があることは、ack、SLA 対応、自動 retry、provider 正常判定が完了したことを意味しません。
- error preview は画面表示と同じく mask / truncate 済みです。PR や issue comment へ貼る場合も、raw provider payload、credential、private path、signed URL、full error log を別途追記しないでください。

候補 0 件の digest も、現在の抽出条件で渡す対象がないことだけを示します。外部 provider 全体の正常性、通知済み、ack 済み、自動 retry 済みの代替証跡としては使いません。

## やらないこと

この候補表示は次の機能ではありません。

- 通知 channel
- alert rule
- ack / escalation
- 自動 retry
- provider contract 変更
- Google Drive / Microsoft Graph 同期本体の変更

原因確認や再実行判断は、同期設定詳細の `同期履歴` と `結果詳細` を正本として確認してください。

## 関連

- [外部フォルダ同期dry-run・apply運用 runbook](./外部フォルダ同期dry-run・apply運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
