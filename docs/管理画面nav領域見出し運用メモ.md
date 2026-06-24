# 管理画面 nav 領域見出し運用メモ

このメモは、管理画面共通 nav の dropdown、領域見出し、active cue の読み方を短く残す。詳しい日常確認手順は [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md) や各 runbook を正本にする。

## current UI

ログイン後の header は、利用者共通の `文書` / `履歴照会` dropdown と、admin user 向けの `管理メニュー` / `連携メニュー` dropdown を表示する。各 dropdown summary は、現在開いている route がその dropdown に属する場合に `現在` badge と current child label を表示する。

`管理メニュー` dropdown の menu 内 section は次の通り。

- `管理ホーム`: `管理画面`
- `マスタ管理`: `会社`、`ユーザー`、`案件`、`案件メンバー`、`同意文言`、`案件同意設定`
- `文書管理`: `文書`、`文書セット`、`文書権限`、`アクセス申請`、`文書一括編集`
- `診断`: `モデルブラウザ`

`連携メニュー` dropdown の menu 内 section は次の通り。

- `仕様確認`: `API仕様`
- `取込・同期`: `Git取込元`、`Git取込履歴`、`Microsoft Graph`、`外部フォルダ同期`
- `通知連携`: `Webhook`

`#3791` の first slice 以降、dropdown menu に直接 link が出ない代表運用 route でも、現在地の読み取り用に summary 側の active cue / current child label へ含めている。

| dropdown | current child label に含める代表運用 route | 読み方 |
| --- | --- | --- |
| `管理メニュー` | `生成ファイル実行履歴`、`生成ファイルイベント`、`定期ジョブ` | 生成ファイル・定期ジョブ系の運用 page は管理系の現在地として読む |
| `連携メニュー` | `Webhook送信履歴`、`単体ファイルdry-run` | 送信履歴や単体 import dry-run は外部連携 / 取込系の現在地として読む |

current child label は、現在地を短く確認するための表示補助であり、dropdown menu の link 追加、route 追加、認可変更、管理画面の情報設計変更を意味しない。

company master admin 向け nav は、従来どおり `会社` と `ユーザー` だけを表示する。`管理メニュー` / `連携メニュー` の dropdown と current child label は internal admin 向け nav の探索 cue であり、role boundary や link 先を変えるものではない。

## 読み方

- dropdown summary の `現在` badge は、移動後に今いる画面がどの大きな menu に属するかを短く確認するための補助として読む。
- current child label は、現在地の代表名を summary 上で読むための補助であり、menu 内に同名 link が常に存在するとは限らない。
- `管理メニュー` は、管理ホーム、マスタ管理、文書管理、診断、および生成ファイル / 定期ジョブ系の運用 page の現在地 cue をまとめる。
- `連携メニュー` は、API仕様、Git取込元、Microsoft Graph、外部フォルダ同期、Webhook、および Webhook送信履歴 / 単体ファイルdry-run の現在地 cue をまとめる。
- `履歴照会` は、利用者履歴と admin の監査・管理履歴をまとめる。`Git取込履歴` は menu link としては `履歴照会` 側で active になり、`連携メニュー` 内の同名 link は補助導線として active 扱いしない。

## 非目標

- nav の role boundary、route、link text の再設計
- dropdown menu の link 追加・削除
- sidebar / accordion 化
- 管理画面ごとの操作手順の置き換え
- company master admin の権限拡張
- narrow viewport の visual evidence 取得