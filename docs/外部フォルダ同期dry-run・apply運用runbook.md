# 外部フォルダ同期dry-run・apply運用 runbook

この文書は issue `#628` に対応する、`docs-portal` の外部フォルダ同期運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、次の画面が外部フォルダ同期の確認入口です。

- `外部フォルダ同期設定`: `admin/external_folder_sync_sources`
- `外部フォルダ同期設定詳細`: 各同期元の詳細画面
- `Microsoft Graph接続`: SharePoint / OneDrive の準備で先に確認する接続設定画面

一覧と詳細で役割が分かれています。

- 一覧では、案件ごとの同期状態、`最新安全判定`、`競合・重複警告`、`最新エラー` を俯瞰する
- 詳細では、Google Drive source なら `同期プレビュー`、`同期する`、`警告を承認して同期する`、`バックグラウンド同期を登録`、変更通知の購読を操作する
- SharePoint / OneDrive source では、保存済み metadata と未対応の同期本体の境界を確認する
- 新規登録 card では、Google Drive の同期レーンと SharePoint / OneDrive の metadata 保存レーンを読み分ける
- 一覧上部の `一覧の絞り込み` では、`warning あり` `error あり` `無効` `Google Drive` `SharePoint / OneDrive` に切り替えて daily review の対象を絞れる
- current `main` では review 絞り込みは一覧専用で、`設定詳細` / `編集` / 詳細画面の `一覧へ戻る` では filter 条件は引き継がれない

## 2. 最初の切り分け順

1. 対象の同期元が既にあるか、新規登録から始めるかを一覧で確認する
2. 必要に応じて `一覧の絞り込み` で `warning あり` `error あり` `無効` `Google Drive` `SharePoint / OneDrive` を切り替え、今日確認したい対象だけに寄せる
3. 新規登録する場合は、先頭 card の `Google Drive から始める` と `SharePoint / OneDrive を準備する` のどちらに当たるかを先に切り分ける
4. Google Drive の既存同期元で `Google OAuthが未接続` の案内が出ているなら、まず接続を済ませる
5. SharePoint / OneDrive source を新規保存した場合は、詳細画面で `drive_id` / `folder_item_id` / `folder_path` / `site_id` が取れているかを先に確認する
6. 初回取り込みや変更確認では、Google Drive source に対して先に `同期プレビュー` を実行する
7. warning や error が出たら、詳細画面の `同期履歴` と `結果詳細` を見る
8. 継続運用で自動検知まで使うなら、Google Drive source の `バックグラウンド同期` と `変更通知の購読` を確認する

## 3. 一覧で見ること

`外部フォルダ同期設定` 一覧では次を確認します。

- `対象案件`: project 名と code
- `同期設定名`: 詳細画面への入口
- `連携先`: provider-aware な見出しで表示される同期元。current `main` では Google Drive は保存から同期まで、SharePoint / OneDrive は metadata 保存まで扱います
- `外部フォルダID`: 保存済み外部フォルダ ID と表示用 path
- `同期状態`: 有効 / 無効
- `最終同期日時`: 直近の同期時刻
- `最新安全判定`: 直近 run の安全判定
- `競合・重複警告`: 直近 run に残っている warning 件数
- `最新エラー`: 直近 run または source に残る error

`一覧の絞り込み` は、同期元が増えたときに daily review の入口になります。

- `warning あり`: 直近 run に `競合・重複警告` が残っている同期元だけを見る
- `error あり`: 直近 run または source に `最新エラー` が残っている同期元だけを見る
- `無効`: いま同期に使っていない設定だけを見直す
- `Google Drive`: 同期本体の運用対象だけに絞る
- `SharePoint / OneDrive`: metadata-only source だけに絞り、保存済み `drive_id` や `folder_path` の確認へ寄る

`最新安全判定` と `競合・重複警告` は、詳細画面の `同期履歴` に出る直近 run と同じ文脈で見ます。件数や判定が気になる同期元は、一覧から `設定詳細` へ入って確認します。

current `main` の注意点:

- review filter は一覧だけに付き、`設定詳細` / `編集` / `一覧へ戻る` では保持されません
- `warning あり` や `error あり` だけを続けて点検したいときは、一覧へ戻ったあとに同じ filter を再度選び直します
- 同じ source を詳しく見たあとに一覧へ戻るだけなら、ブラウザの戻る操作の方が文脈を保ちやすいことがあります

まだ同期元が 0 件のときは table は表示されず、一覧の代わりに empty state が出ます。この状態では上部の `外部フォルダ同期設定を追加` card が最初の入口です。`対象案件`、`同期設定名`、`同期元プロバイダ`、`外部フォルダURL` を埋めて最初の 1 件を保存し、SharePoint / OneDrive を選ぶ場合は先に `Microsoft Graph接続` を用意してから戻ります。

## 4. 新規登録 card の読み方

`外部フォルダ同期設定` 一覧の上部にある新規登録 card は provider-aware な入口です。0 件時の empty state もこの読み分けを前提にしており、何も登録されていない段階では一覧性よりこの card の初回入力導線を優先して読みます。ここで見分けるのは「この画面で今すぐ保存できるか」と「保存後にどこまで進められるか」です。

### `Google Drive から始める`

- `対象案件` と `外部フォルダURL` に Google Drive フォルダ URL を入れます
- `接続方式` は通常 `OAuthユーザー方式` を選びます
- 保存後に詳細画面で `Google OAuthを接続` し、`同期プレビュー` で対象ファイルと warning を確認します
- `サービスアカウントJSON` は Google Drive をサービスアカウント方式で扱う場合だけ入力します

### `SharePoint / OneDrive を準備する`

- 先に `Microsoft Graph接続を確認` から、対象案件に有効な `Microsoft Graph接続` があるか見直します
- `同期元プロバイダ` に `SharePoint / OneDrive`、`接続方式` に `Microsoft Graph接続` を選び、共有 URL を入力して保存します
- 保存時に `drive_id` / `folder_item_id` / `folder_path` / `site_id` を自動解決し、詳細画面で確認できます
- `dry_run` / `apply` / `enqueue` / 変更通知は後続 issue の範囲なので、この runbook では保存済み metadata の確認までを current support として扱います

## 5. 詳細画面の `次にやること` の読み方

詳細画面の先頭 card は、直近状態ごとに次アクションを出し分けています。

### SharePoint / OneDrive metadata-only source

SharePoint / OneDrive source では、共有 URL からフォルダ metadata を保存できたことを確認します。

- `Microsoft Graph接続を確認` で対象案件の接続を見直す
- `Drive ID`、`Folder item ID`、`Folder path`、必要なら `Site ID` を確認する
- 詳細画面の案内どおり、差分同期本体と変更通知は後続 issue 範囲として切り分ける

### Google OAuth 未接続

`OAuthユーザー方式` で refresh token が未保存のときは、最初に `Google OAuthを接続` を押します。接続後に `同期プレビュー` で読めるファイルを確認します。

### まだ run がない、または直近 run が dry-run

`まず同期プレビューを実行` の案内が出ます。最初の確認や変更点の見直しは、Google Drive source ではここから始めます。

### 直近 dry-run に競合・重複警告がある

`警告を承認して同期する` が出ます。先に `結果詳細` で warning の中身を見て、内容を理解したときだけ `force apply` 相当の操作を使います。

### 通常状態

`同期プレビュー` と `同期する` の両方が出ます。差分確認が目的なら `同期プレビュー`、取り込みを進めるなら `同期する` を使います。

詳細画面からの戻り方:

- `一覧へ戻る` は常に `外部フォルダ同期設定` 一覧へ戻ります
- current `main` では、どの review filter から入ったかまでは保持しません
- `編集` へ進んで保存したあとも詳細画面へ戻るため、一覧の review filter を続けて使うときは一覧へ戻ってから選び直します

## 6. 操作の使い分け

SharePoint / OneDrive source は first slice として metadata 保存までなので、この節の操作説明は Google Drive source を前提に読みます。SharePoint / OneDrive source では `dry_run` / `apply` / `enqueue` / 変更通知に進まず、接続と保存済み metadata の確認を優先してください。

### `同期プレビュー`

`dry_run` です。取り込まれるファイル、skip、warning、要確認を先に確認します。初回取り込みや、外部側の更新を確認したいときはこれを先に使います。

### `同期する`

`apply` です。実際に portal へ取り込みます。current confirm copy では、競合・重複警告がある場合は自動停止する前提で案内されています。

### `警告を承認して同期する`

`force_apply` 相当です。直近の `dry_run` に競合・重複警告があり、まだ承認済みではないときだけ使います。warning を見ずに通常 `apply` を繰り返すより、何を承認するかを確認してから使う前提です。

### `バックグラウンド同期を登録`

`enqueue` です。継続運用で同期 job を流したいときに使います。直近の `dry_run` に競合・重複警告が残っている間は controller 側でブロックされます。

### `変更通知の購読を開始` / `停止`

Google Drive の変更通知 subscription を管理します。日常運用では、購読状態、期限、直近エラーを `変更通知の購読` card で見返します。

### detail 上の代表操作後の見え方

- `同期プレビュー` `同期する` `警告を承認して同期する` `バックグラウンド同期を登録` の後は、同じ source の詳細画面へ戻ります
- Google Drive の変更通知購読開始 / 停止や OAuth 接続確認も、一覧ではなく詳細画面の文脈で結果を見返す current flow です
- そのため、一覧の review filter で候補を見つけ、詳細画面で 1 件ずつ状態と履歴を確認する、という 2 段階で使い分けます

## 7. `同期履歴` で見ること

詳細画面の `同期履歴` では、各 run ごとに次を確認します。

- `実行日時`
- `実行ID`
- `実行種別`: `dry_run` か `apply`
- `実行状態`: `pending` / `running` / `completed` / `failed` / `partial`
- `安全判定`
- `作成件数` / `更新件数` / `スキップ件数` / `削除検知件数` / `エラー件数`
- `要確認件数`
- `競合・重複警告`
- `警告承認`

さらに `結果詳細` では、path ごとの判定、確認要否、変更理由・警告、message を追えます。warning や error の切り分けは、まずここを見るのが最短です。

## 8. `変更通知` と `同期アイテム` の見方

### 変更通知の購読

購読 card では次を見ます。

- `購読状態`
- `通知チャンネルID`
- `通知リソースID`
- `コールバックURL`
- `有効期限`
- `最終更新日時`
- `エラー`

期限切れや callback error が出ているときは、ここが最初の確認場所です。

### 変更通知の受信イベント

受信イベント card では、受信時刻、処理状態、通知番号、関連 run、重複防止キー、エラー理由を見ます。通知自体は届いているのに同期が進まない場合は、ここから related run をたどります。

### 同期アイテム

`同期アイテム` では path ごとの状態、紐づいた portal 文書、前回変更理由・警告、エラーを見ます。個別 path の warning がどこで出たかを見返すときに使います。

## 9. current support の境界

- 新規登録 UI と一覧見出しは provider-aware で、current `main` では `google_drive` は保存から `dry_run` / `apply` / `enqueue` / 変更通知まで、`microsoft_graph` は共有 URL から metadata 保存と保存済み metadata の確認まで進められます
- current sync direction は `external_to_portal` のみです
- current conflict policy は `manual` 前提です
- SharePoint / OneDrive を同期元として `dry_run` / `apply` / `enqueue` / 変更通知まで進める運用は未対応です
- SharePoint / OneDrive source で見える `Drive ID` / `Folder item ID` / `Folder path` / `Site ID` は、共有 URL から解決して保存できた metadata を確認するためのものです

この runbook は current `main` の Google Drive 運用を正本にしつつ、SharePoint / OneDrive では何が `今できること` かを maintainer が誤読しないよう補っています。

## 10. 関連文書

- [preview 接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
- [Google Drive外部フォルダ同期](./Google%20Drive%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md)
- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
- [README](../README.md)
- [docs/README](./README.md)
