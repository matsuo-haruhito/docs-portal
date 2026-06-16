# 生成ファイル再試行 UI cue 補足

このメモは、`docs/生成ファイル再試行と定期ジョブ管理runbook.md` の補足として、生成ファイルイベント / 生成ファイル実行履歴の再試行 UI cue を current main に合わせて読むためのものです。

Refs #2926 / #3233 / #3238。

## 対象画面

- `admin/generated_file_runs/:public_id`
- `admin/generated_file_events/:public_id`
- `admin/generated_file_events`

## detail の単体再試行 cue

生成ファイル実行履歴 detail の右上 button は `この実行を再実行` です。対象は表示中の 1 run だけで、`title` / `aria-label` には対象 run の `public_id` と「再実行キューに投入」することが入ります。

生成ファイルイベント detail の右上 button は `このイベントを再dispatch` です。対象は表示中の 1 event だけで、`title` / `aria-label` には対象 event の `public_id` と「再dispatchキューに投入」することが入ります。

どちらも一覧の一括操作とは別の単体操作です。複数件をまとめて処理したい場合は、detail ではなく一覧の filter と一括操作 cue を確認します。

## event 一括再dispatchの確認 dialog

生成ファイルイベント一覧の `失敗分を一括再dispatch` は、対象が 1 件以上ある場合だけ確認 dialog を出します。dialog では次を読み直します。

- 現在の条件に一致する失敗イベントの対象件数
- 古い順に最大 100 件を一括再dispatchすること
- 現在の条件を確認してから実行すること

対象が 0 件の場合、button は disabled のままで、実行可能な確認 dialog は出ません。

## runbook 本体と合わせて読む境界

この補足は UI cue の追従だけを扱います。次の contract は既存 runbook 本体の説明を正本にします。

- event 再dispatchと run 再実行の違い
- current filter に一致する failed event / failed run を古い順最大 100 件まで扱うこと
- scheduled / created date filter、path / q、status filter の読み方
- `return_to`、関連 event / run、retry 親子 metadata の読み方

## 非目標

- retry / redispatch の業務ロジック変更
- 一括対象件数の上限変更
- preview route、承認 workflow、自動 retry、通知 channel の追加
- `return_to` safety boundary の再定義
