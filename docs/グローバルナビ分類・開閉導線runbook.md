# グローバルナビ分類・開閉導線 runbook

## 目的

この runbook は、ログイン後の共通 navbar で `文書`、`履歴照会`、`管理メニュー`、`連携メニュー` のどこから目的の画面へ進むかを読み分けるための入口です。current main の `app/views/shared/_navbar.html.slim` と `nav-dropdowns` controller の挙動に合わせ、利用者・管理者向け docs から参照できる最小の導線として扱います。

## メニュー分類

### 文書

`文書` は日常利用の入口です。一般利用者と internal user が、案件や文書を見に行くときはまずここを見ます。

- `ダッシュボード`: 自分に関係する文書、申請、確認依頼への起点
- `案件一覧`: 案件単位で文書一覧へ進む起点
- `ショートカット`: お気に入り、後で読む、最近見た文書の確認
- `アクセス申請`: 文書閲覧・ダウンロード権限を申請する入口
- `確認依頼`: internal user 向けの社内確認依頼入口

`確認依頼` は internal user 向けです。外部利用者が使える日常導線として説明しないでください。

### 履歴照会

`履歴照会` は、利用履歴や送付履歴、管理者向けの監査・管理履歴を確認する入口です。通常の文書閲覧や管理設定を始める場所ではありません。

- `送付履歴`: 文書送付の状態や失敗記録を確認する
- `注意事項・同意履歴`: 利用上の注意事項や同意履歴を確認する
- `アクセスログ`: admin user が文書アクセスの記録を確認する
- `文書利用レポート`: admin user が文書利用状況を確認する
- `Git取込履歴`: admin user が Git import run の履歴を確認する

`Git取込履歴` は `連携メニュー` にも入口があります。履歴を調べるときは `履歴照会`、Git 取込元や同期設定へ進むときは `連携メニュー` と読み分けます。

### 管理メニュー

`管理メニュー` は admin user 向けのマスタ管理・文書管理・診断入口です。一般利用者向け runbook では current support として扱いません。

- `管理画面`: admin dashboard
- `会社` / `ユーザー` / `案件` / `案件メンバー`: マスタ管理
- `同意文言` / `案件同意設定`: 同意管理
- `文書` / `文書セット` / `文書権限` / `アクセス申請` / `文書一括編集`: 文書管理
- `モデルブラウザ`: read-only なモデル観測と診断

### 連携メニュー

`連携メニュー` は admin user 向けの仕様確認、取込・同期、通知連携の入口です。外部連携や preview / sync の設定を確認するときに使います。

- `API仕様`: API 仕様ページと docs-src 生成物の確認
- `Git取込元` / `Git取込履歴`: Git 連携設定と import run の確認
- `Microsoft Graph`: Office preview や Graph 接続の確認
- `外部フォルダ同期`: 外部フォルダ同期 source / dry-run / apply の確認
- `Webhook`: Webhook endpoint と送信履歴の確認

SharePoint / OneDrive の同期本体、Graph delta sync、Webhook 自動 retry など、各 runbook で未対応としている範囲はこのメニュー分類だけで current support になったとは扱いません。

## 現在位置 cue

navbar は現在表示中の画面を読みやすくするため、該当する menu item と親 dropdown に `現在` badge を出します。現在ページの menu item には `aria-current="page"` も付きます。

- `文書`、`履歴照会`、`管理メニュー`、`連携メニュー` のいずれか配下にいる場合、親 summary に `現在` badge が表示されます。
- dropdown 内の現在ページ link にも `現在` badge が表示されます。
- `Git取込履歴` は `履歴照会` と `連携メニュー` の両方に入口がありますが、現在位置 cue は履歴確認の入口である `履歴照会` 側だけに出します。
- 外部利用者や権限のない利用者には、そもそも表示されない admin / internal 専用導線があります。`現在` badge は role visibility を広げるものではありません。

この cue は現在位置を読むための表示補助です。navbar の分類、routing、role gate、メニュー item の追加・削除、保存済み開閉状態を変更する仕様として扱わないでください。

## 開閉とキーボード操作

`nav-dropdowns` controller は、dropdown の開閉を補助します。

- ある dropdown を開くと、他に開いている dropdown は閉じます。
- dropdown の外側を click すると、開いている dropdown は閉じます。
- Escape を押すと、開いている dropdown は閉じ、閉じた dropdown の summary に focus が戻ります。

この挙動は navbar の操作補助です。キーボードショートカット一覧、保存済み状態、メニューの永続展開、role visibility の変更として説明しないでください。

## docs 更新時の確認観点

- 利用者向け docs では `文書` と `履歴照会` を中心に説明し、admin user 専用の `管理メニュー` / `連携メニュー` を一般利用者の current support として書かない。
- admin runbook では、マスタ・文書管理は `管理メニュー`、外部連携や import / sync は `連携メニュー` と読み分ける。
- 履歴調査は `履歴照会` を入口にする。ただし設定や再同期の操作は該当する admin / 連携 runbook へ戻す。
- `現在` badge と `aria-current="page"` は現在位置を読む cue として説明し、role visibility や menu 構成変更として扱わない。
- navbar の情報設計変更、menu item の追加・削除、role visibility の変更、Stimulus controller の実装変更はこの docs の範囲外です。
