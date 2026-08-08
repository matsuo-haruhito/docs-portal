# 外部フォルダ同期 webhook ignored event の読み分け

このメモは issue `#1355` の first slice として、Google Drive 変更通知の受信イベントが `ignored` になったときの読み分けを固定します。`docs/runbooks/external/外部フォルダ同期dry-run・apply運用runbook.md` の「変更通知の受信イベント」と合わせて確認します。

## 処理状態の見方

`外部フォルダ同期設定詳細` の `変更通知の受信イベント` card では、`ignored` の理由を次の表示で読み分けます。

| 表示 | 意味 | 次に見る場所 |
| --- | --- | --- |
| `無視（実行中のため集約）` | 同じ同期元の running run が実行権を保持しているため、追加の webhook event を follow-up 対象として待機させました。 | `同期履歴` の running run、最終ハートビート、完了後の結果詳細 |
| `無視（登録済みジョブへ集約）` | 同じ同期元の pending run が実行権を保持しているため、追加 enqueue を抑制しました。 | `同期ジョブ登録済み` event、pending run、実行権の期限 |
| `無視（同期元なし / 無効）` | webhook event に対応する同期元が存在しない、または同期元が無効です。 | 同期元の有効状態、購読状態、通知チャンネル ID |
| `無視（要確認）` | 既知の coalesced / source unavailable 以外の ignored 理由です。 | `エラー理由` の保存値と直近の変更履歴 |

## 運用上の境界

- `ignored` status 自体は増やしません。既存の enqueue 抑制と status 遷移を保ったまま、表示と helper で読み分けます。
- `無視（実行中のため集約）` と `無視（登録済みジョブへ集約）` は恒久的な失敗ではなく、source単位の実行権が二重起動を防いでいる状態です。後着eventは `received` のまま保持し、owner run完了後のfollow-up runへ集約します。
- `無視（同期元なし / 無効）` はrun予約前に同期元が存在しない、または無効と確定したeventです。設定またはsubscriptionの確認対象であり、coalescedと同じ対応にしないでください。
- run予約・claim後にprovider、同期方向、有効状態のpreflightで失敗した場合は`ignored`へ戻しません。current ownerがrunを`failed`へ確定してsource leaseを解除し、関連runと`sync_run` summaryを保持したままeventも`failed`へ収束させます。恒久設定エラーを`received`へ戻して再処理loopにしません。
- 失敗確定時にclaim tokenが交代済みなら、旧ownerはrun / source / eventを更新しません。`StaleClaimError`はreplacementが確定した状態を保護するfenceとして扱います。
- 2分のcoalesce windowは短時間の通知を同じ予約へまとめるためのdebounce値であり、排他保証ではありません。activeなpending / running runとsourceのleaseが存在する間は、2分を超えても別runを予約しません。
