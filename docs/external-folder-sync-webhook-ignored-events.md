# 外部フォルダ同期 webhook ignored event の読み分け

このメモは issue `#1355` の first slice として、Google Drive 変更通知の受信イベントが `ignored` になったときの読み分けを固定します。`docs/外部フォルダ同期dry-run・apply運用runbook.md` の「変更通知の受信イベント」と合わせて確認します。

## 処理状態の見方

`外部フォルダ同期設定詳細` の `変更通知の受信イベント` card では、`ignored` の理由を次の表示で読み分けます。

| 表示 | 意味 | 次に見る場所 |
| --- | --- | --- |
| `無視（実行中のため集約）` | 同じ同期元の run が実行中のため、追加の webhook event を既存処理へ集約しました。 | `同期履歴` の running run と、完了後の結果詳細 |
| `無視（登録済みジョブへ集約）` | 直近 2 分以内に同じ同期元の webhook sync job が登録済みのため、追加 enqueue を抑制しました。 | 直近の `同期ジョブ登録済み` event と関連 run |
| `無視（同期元なし / 無効）` | webhook event に対応する同期元が存在しない、または同期元が無効です。 | 同期元の有効状態、購読状態、通知チャンネル ID |
| `無視（要確認）` | 既知の coalesced / source unavailable 以外の ignored 理由です。 | `エラー理由` の保存値と直近の変更履歴 |

## 運用上の境界

- `ignored` status 自体は増やしません。既存の enqueue 抑制と status 遷移を保ったまま、表示と helper で読み分けます。
- `無視（実行中のため集約）` と `無視（登録済みジョブへ集約）` は恒久的な失敗ではなく、過剰 enqueue を避けるための coalescing です。
- `無視（同期元なし / 無効）` は設定または subscription の確認対象です。coalesced と同じ対応にしないでください。
- coalesce window は current implementation の `2.minutes` を維持します。この値を変える場合は別 issue で運用影響を確認します。
