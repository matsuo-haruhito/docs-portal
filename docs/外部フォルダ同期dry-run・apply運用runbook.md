# 外部フォルダ同期dry-run・apply運用 runbook

この文書は issue `#628` に対応する、`docs-portal` の外部フォルダ同期運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、次の画面が外部フォルダ同期の確認入口です。

- `外部フォルダ同期設定`: `admin/external_folder_sync_sources`
- `外部フォルダ同期設定詳細`: 各同期元の詳細画面
- `Microsoft Graph接続`: SharePoint / OneDrive の準備で先に確認する接続設定画面

一覧と詳細で役割が分かれています。

- 一覧では、案件ごとの同期状態、`最新安全判定`、`直近run` cue、`競合・重複警告`、`最新エラー` とその由来 cue を俯瞰する
- 詳細では、Google Drive source なら `同期プレビュー`、`同期する`、`警告を承認して同期する`、`バックグラウンド同期を登録`、変更通知の購読を操作する
- SharePoint / OneDrive source では、保存済み metadata と未対応の同期本体の境界を確認する
- 新規登録 card では、案件コード / 案件名で対象案件を検索し、Google Drive の同期レーンと SharePoint / OneDrive の metadata 保存レーンを読み分ける
- 一覧上部の `一覧の絞り込み` では、`warning あり` `error あり` `無効` `Google Drive` `SharePoint / OneDrive` に切り替え、必要に応じて同期設定名、案件名 / code、外部フォルダ ID / path で検索できる

## Provider support matrix

README からこの runbook へ入ったときは、まず次の表で provider ごとの current support と未対応範囲を切り分けます。外部同期に見える項目でも、Git import は `Git連携` / `Git同期履歴` の別画面、Google Drive は同期本体の運用対象、SharePoint / OneDrive は共有 URL から metadata を保存し、保存済み metadata を確認するレーンとして扱います。

| provider / 入口 | current support | 未対応・確認範囲 |
| --- | --- | --- |
| Git / GitHub import (`admin/git_import_sources`, `admin/git_import_runs`) | `github` provider の repository / branch / path を登録し、pull 型の手動同期と run 履歴を確認できます。詳しい操作は [Git連携設定と同期失敗確認runbook](./Git%E9%80%A3%E6%90%BA%E8%A8%AD%E5%AE%9A%E3%81%A8%E5%90%8C%E6%9C%9F%E5%A4%B1%E6%95%97%E7%A2%BA%E8%AA%8Drunbook.md) を正本にします。 | GitHub App / webhook / 定期同期の完成は `#1028`、Git 側削除の自動 archive / delete は未対応です。 |
| Google Drive (`google_drive` source) | `外部フォルダ同期設定` で folder URL を保存し、OAuth ユーザー方式またはサービスアカウント方式を使って `dry_run` / `apply` / `force_apply` / `enqueue` / 変更通知購読まで進められます。 | native Google Docs export、権限同期、削除 policy の拡張は未対応です。古い `#1029` は「Google Drive 追加」ではなく current support の再確認対象として扱います。 |
| SharePoint / OneDrive (`microsoft_graph` source) | `Microsoft Graph接続` を前提に共有 URL を保存し、`drive_id` / `folder_item_id` / `folder_path` / `site_id` などの metadata を詳細画面で確認できます。SharePoint webhook route は validation token 応答と notification payload 記録の受け口として存在します。 | Graph -> Portal の pull 型同期本体、`dry_run` / `apply` / `enqueue` / 変更通知の購読運用はこの画面ではまだ実行できません。webhook route があるだけでは、SharePoint / OneDrive の変更通知を運用可能とは扱いません。 |

## 2. 最初の切り分け順

1. 対象の同期元が既にあるか、新規登録から始めるかを一覧で確認する
2. 必要に応じて `一覧の絞り込み` で `warning あり` `error あり` `無効` `Google Drive` `SharePoint / OneDrive` を切り替え、今日確認したい対象だけに寄せる
3. 同期元が増えている場合は、検索欄で同期設定名、案件名 / code、外部フォルダ ID / path を指定し、review/provider filter と併用して対象を絞る。検索語は空白を整えた最大100文字で扱われるため、長いフォルダ URL や error 断片は特徴的な一部で探す
4. 条件一致件数が多い場合は、一覧上部の `条件一致 N 件中 X-Y 件` と `前へ` / `次へ` を使って page 移動する。page 移動は検索語、review/provider filter、1ページあたりの上限を保持する
5. 新規登録する場合は、対象案件を案件コード / 案件名で検索し、先頭 card の `Google Drive から始める` と `SharePoint / OneDrive を準備する` のどちらに当たるかを先に切り分ける
6. Google Drive の既存同期元で `Google OAuthが未接続` の案内が出ているなら、まず接続を済ませる
7. SharePoint / OneDrive source を新規保存した場合は、詳細画面で `drive_id` / `folder_item_id` / `folder_path` / `site_id` が取れているかを先に確認する
8. 初回取り込みや変更確認では、Google Drive source に対して先に `同期プレビュー` を実行する
9. warning や error が出たら、詳細画面の `同期履歴` と `結果詳細` を見る
10. 継続運用で自動検知まで使うなら、Google Drive source の `バックグラウンド同期` と `変更通知の購読` を確認する

## 3. 一覧で見ること

`外部フォルダ同期設定` 一覧では次を確認します。

- `対象案件`: project 名と code
- `同期設定名`: 詳細画面への入口
- `連携先`: provider-aware な見出しで表示される同期元。current `main` では Google Drive は保存から同期まで、SharePoint / OneDrive は metadata 保存まで扱います
- `外部フォルダID`: 保存済み外部フォルダ ID と表示用 path
- `同期状態`: 有効 / 無効
- `最終同期日時`: 直近の同期時刻
- `最新安全判定`: 直近 run の安全判定と `直近run: 時刻 / 実行種別 / 状態` cue
- `競合・重複警告`: 直近 run に残っている warning 件数
- `最新エラー`: 直近 run または source に残る error の一覧向け safe preview と `由来: 直近run` / `由来: 同期元metadata` cue

`一覧の絞り込み` は、同期元が増えたときに daily review の入口になります。

- 検索欄: 同期設定名、案件名 / code、外部フォルダ ID、保存済み `external_folder_path` から部分一致で探す。検索語は前後空白と連続空白を整えたうえで最大100文字まで使われ、検索欄にも同じ上限 cue が表示されます。長い folder URL や error message は、特徴的な path / id / name 断片に短くして探します
- `warning あり`: 直近 run に `競合・重複警告` が残っている同期元だけを見る
- `error あり`: 直近 run または source に `最新エラー` が残っている同期元だけを見る
- `無効`: いま同期に使っていない設定だけを見直す
- `Google Drive`: 同期本体の運用対象だけに絞る
- `SharePoint / OneDrive`: metadata-only source だけに絞り、保存済み `drive_id` や `folder_path` の確認へ寄る

検索条件は review/provider filter と併用できます。filter link は検索条件を保持し、`検索を解除` は review/provider filter を残します。詳細・編集画面へ進む link も、整えた検索語と review/provider filter を含む `return_to` を保持するため、確認後に同じ一覧条件へ戻れます。page 2 以降から詳細・編集・削除に進む場合は、`return_to` に現在の `page` と、指定されていれば `per_page` も残ります。空白だけの検索語は検索なしとして扱われます。検索 / 絞り込み結果が 0 件の場合は、未登録の empty state ではなく「現在の検索 / 絞り込みに一致しない」状態として扱います。

一覧は条件一致した同期元に対して bounded pagination されます。既定は 1 ページ 10 件で、`per_page` が渡された場合も最大 50 件に丸められます。表示 summary は、現在ページの行数、全同期元件数、条件一致件数、`X-Y件` の表示範囲を分けて読みます。`前へ` / `次へ` は検索語、review/provider filter、`per_page` を維持します。`warnings` / `errors` filter は直近 run や source metadata による判定を先に行い、その後の条件一致結果に対して page が切られるため、DB offset 先行で警告対象が欠ける意味ではありません。無効な `page` は有効範囲に丸められ、削除や filter 不一致とは読みません。

`最新安全判定` と `競合・重複警告` は、詳細画面の `同期履歴` に出る直近 run と同じ文脈で見ます。一覧では安全判定の下に `直近run: 時刻 / 実行種別 / 状態` が出るため、warning filter で見つけた行がどの run の結果かを先に読みます。まだ run がない同期元は `直近runなし` と表示されるので、Google Drive source なら詳細画面で初回 `同期プレビュー` から始めます。

`最新エラー` は一覧で異常の有無を素早く見つけるための safe preview です。error が直近 run に残っている場合は `由来: 直近run`、run 側には error がなく source の metadata に残っている場合は `由来: 同期元metadata` と表示されます。この由来 cue は調査入口を分けるための補助であり、error taxonomy、件数計算、retry、metadata 再確認、同期実行の挙動を変えるものではありません。token / secret / password / authorization 風の値や private-looking path は一覧上で raw 表示されず、長い message も短く省略されます。全文調査や path ごとの判定を確認したい場合は、`error あり` で対象を絞ったあと `設定詳細` へ入り、`同期履歴` と `結果詳細` を見ます。一覧の preview だけで provider API、retry、apply、storage schema の原因を断定しないでください。

まだ同期元が 0 件のときは table は表示されず、一覧の代わりに empty state が出ます。この状態では上部の `外部フォルダ同期設定を追加` card が最初の入口です。`対象案件`、`同期設定名`、`同期元プロバイダ`、`外部フォルダURL` を埋めて最初の 1 件を保存し、SharePoint / OneDrive を選ぶ場合は先に `Microsoft Graph接続` を用意してから戻ります。0 件 empty state に出る `Microsoft Graph接続を確認する` link も、同期実行ではなく SharePoint / OneDrive の接続状態を保存前に見直すための入口として扱います。

## 4. 新規登録 card の読み方

`外部フォルダ同期設定` 一覧の上部にある新規登録 card は provider-aware な入口です。0 件時の empty state もこの読み分けを前提にしており、何も登録されていない段階では一覧性よりこの card の初回入力導線を優先して読みます。ここで見分けるのは「この画面で今すぐ保存できるか」と「保存後にどこまで進められるか」です。

`対象案件` は案件コード / 案件名で検索する remote combobox です。検索語は前後空白を除いた最大100文字で扱われ、候補は最大20件です。編集画面や validation error 後の再表示では、候補上限外の保存済み案件も `コード / 案件名` の selected option として復元されます。目的の案件が出ない場合は、検索語を短い code / name 断片に戻して探し直し、案件自体が未登録か権限外かは案件管理側で確認してください。

### `Google Drive から始める`

- `対象案件` で案件コード / 案件名を検索し、Google Drive フォルダ URL を入れます
- `接続方式` は通常 `OAuthユーザー方式` を選びます
- `サービスアカウントJSON` は Google Drive をサービスアカウント方式で扱う場合だけ入力します
- 保存後に詳細画面で `Google OAuthを接続` し、`同期プレビュー` で読めるファイルを確認します

### `SharePoint / OneDrive を準備する`

- 先に `Microsoft Graph接続を確認` から、対象案件に有効な `Microsoft Graph接続` があるか見直します
- `対象案件` で案件コード / 案件名を検索します
- `同期元プロバイダ` に `SharePoint / OneDrive`、`接続方式` に `Microsoft Graph接続` を選び、共有 URL を入力して保存します
- 保存時に `drive_id` / `folder_item_id` / `folder_path` / `site_id` を自動解決し、詳細画面で確認できます
- `dry_run` / `apply` / `enqueue` / 変更通知はこの画面ではまだ実行できないため、この runbook では保存済み metadata の確認までを current support として扱います

## 5. 詳細画面の `次にやること` の読み方

詳細画面の先頭 card は、直近状態ごとに次アクションを出し分けています。

### SharePoint / OneDrive metadata-only source

SharePoint / OneDrive source では、共有 URL からフォルダ metadata を保存できたことを確認します。

- `Microsoft Graph接続を確認` で対象案件の接続を見直す
- `Drive ID`、`Folder item ID`、`Folder path`、必要なら `Site ID` を確認する
- `保存済み metadata を再確認` は同期本体を実行せず、保存済み Drive ID / Folder item ID / Folder path / Site ID と、現在の Microsoft Graph 解決結果を read-only に比較する
- 再確認後は、画面内の `保存済み metadata 再確認結果` で `一致` または `差分あり` の field label を読む。ここに出るのは field label だけで、解決後の raw 値、secret-like value、長い Graph error を確認する場所ではない
- `差分あり` の場合でも保存済み metadata は自動更新されない。必要なら `設定を編集` から共有 URL や接続を見直し、保存し直す
- 詳細画面の案内どおり、差分同期本体と変更通知はこの画面ではまだ実行できない current support 外として切り分ける

### Google OAuth 未接続

`OAuthユーザー方式` で refresh token が未保存のときは、最初に `Google OAuthを接続` を押します。接続後に `同期プレビュー` で読めるファイルを確認します。

### 直近 dry-run に競合・重複警告がある

`警告を承認して同期する` が出ます。ボタン付近には、直近 `dry_run` の warning 件数と代表 path / message が表示されます。先にその要約と下の `同期履歴` の `結果詳細` を見て、内容を理解したときだけ `force apply` 相当の操作を使います。

### まだ run がない、または直近 run が warning なしの dry-run

`まず同期プレビューを実行` の案内が出ます。最初の確認や変更点の見直しは、Google Drive source ではここから始めます。

### 通常状態

`同期プレビュー` と `同期する` の両方が出ます。差分確認が目的なら `同期プレビュー`、取り込みを進めるなら `同期する` を使います。

## 6. 操作の使い分け

SharePoint / OneDrive source は現時点では metadata 保存までなので、この節の操作説明は Google Drive source を前提に読みます。SharePoint / OneDrive source では `dry_run` / `apply` / `enqueue` / 変更通知に進まず、接続と保存済み metadata の確認を優先してください。

### `同期プレビュー`

`dry_run` です。取り込まれるファイル、skip、warning、要確認を先に確認します。初回取り込みや、外部側の更新を確認したいときはこれを先に使います。

### `同期する`

`apply` です。実際に portal へ取り込みます。current confirm copy では、競合・重複警告がある場合は自動停止する前提で案内されています。

### `警告を承認して同期する`

`force_apply` 相当です。直近の `dry_run` に競合・重複警告があり、まだ承認済みではないときだけ使います。画面には承認対象の warning 件数と代表 path / message が出ますが、全件確認の正本は `同期履歴` の `結果詳細` です。warning を見ずに通常 `apply` を繰り返すより、何を承認するかを確認してから使う前提です。

### `バックグラウンド同期を登録`

`enqueue` です。継続運用で同期 job を流したいときに使います。直近の `dry_run` に競合・重複警告が残っている間は controller 側でブロックされます。

### `変更通知の購読を開始` / `停止`

Google Drive の変更通知 subscription を管理します。日常運用では、購読状態、期限、直近エラーを `変更通知の購読` card で見返します。SharePoint / OneDrive の subscription 作成や購読開始は current support 外です。

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

期限切れや callback error が出ているときは、ここが最初の確認場所です。current support では Google Drive の変更通知購読だけを運用対象にします。

### SharePoint / OneDrive webhook 受信口

current code には `external_folder_sync_webhooks/sharepoint` の GET / POST route があります。GET または POST で `validationToken` が渡された場合は plain text で返し、イベントは記録しません。通常の通知 payload では、`value` 配列があれば配列内の各要素を、単体 payload ならその 1 件を notification として記録します。

通知ごとに `subscriptionId` から subscription を探し、`clientState` が設定済み verification token digest と一致するかを確認します。`clientState` は payload 保存時に `[FILTERED]` へ置き換えられ、`Client-State` や `X-Goog-Channel-Token` のような secret-like header は `headers_json` に raw 保存しません。受信 event が `received` でも、これは webhook payload を受け付けた記録であり、SharePoint / OneDrive 同期本体の dry-run / apply / enqueue が動く保証ではありません。

この受信口は、SharePoint / OneDrive 変更通知の実装準備として読むものです。source 作成、Graph subscription 作成、Graph -> Portal 同期本体、通知を起点にした運用手順は current support 外なので、route や controller があることだけで「SharePoint / OneDrive の変更通知を開始できる」と判断しないでください。

### 変更通知の受信イベント

受信イベント card では、受信時刻、処理状態、通知番号、関連 run、重複防止キー、エラー理由を見ます。Google Drive では、通知自体は届いているのに同期が進まない場合に、ここから related run をたどります。SharePoint / OneDrive では、受信イベントが記録されていても同期本体の運用対象とは扱わず、metadata-only source と current support 外の同期運用を切り分けます。

### 同期アイテム

`同期アイテム` では path ごとの状態、紐づいた portal 文書、前回変更理由・警告、エラーを見ます。個別 path の warning がどこで出たかを見返すときに使います。

## 9. current support の境界

- 新規登録 UI と一覧見出しは provider-aware で、current `main` では `google_drive` は保存から `dry_run` / `apply` / `enqueue` / 変更通知まで、`microsoft_graph` は共有 URL から metadata 保存と保存済み metadata の確認まで進められます
- 一覧検索は同期設定名、案件名 / code、外部フォルダ ID、保存済み `external_folder_path` の部分一致です。検索語は空白を整えて最大100文字に丸められ、review/provider filter、page 移動、詳細 / 編集から戻る `return_to` でも同じ検索条件として保持されます
- 一覧は条件一致結果を既定 10 件、最大 50 件ずつ表示します。`前へ` / `次へ` は検索語、review/provider filter、`per_page` を維持し、invalid page は有効な page に丸められます。table preferences は列表示だけに作用し、page / filter / visible scope の意味を変えません
- 一覧の `最新安全判定` は安全判定に加えて `直近run: 時刻 / 実行種別 / 状態` cue を出します。`最新エラー` は safe preview に加えて `由来: 直近run` または `由来: 同期元metadata` を出します。これらは調査入口の文脈 cue であり、warning / error filter、件数計算、同期 runner、metadata recheck の挙動は変えません
- 新規登録 / 編集フォームの `対象案件` は案件コード / 案件名の remote search で選びます。検索語は最大100文字、候補は最大20件で、保存済み案件は edit / validation rerender で selected option として復元されます
- current sync direction は `external_to_portal` のみです
- current conflict policy は `manual` 前提です
- SharePoint / OneDrive を同期元として `dry_run` / `apply` / `enqueue` / 変更通知の購読運用まで進めることは未対応です
- SharePoint webhook route は validation token 応答と notification payload 記録の受け口として存在します。`value` 配列 payload と単体 notification payload のどちらも受信 event として記録できますが、Graph subscription 作成や通知起点の同期運用ができる状態ではありません
- SharePoint / OneDrive の `clientState` や secret-like header は raw の運用確認値として保存しません。受信 event を調べるときも payload / headers の raw secret を探すのではなく、verification mismatch や subscription / source の紐づきを確認します
- SharePoint / OneDrive source で見える `Drive ID` / `Folder item ID` / `Folder path` / `Site ID` は、共有 URL から解決して保存できた metadata を確認するためのものです
- `保存済み metadata を再確認` は、保存済み metadata と現在の Microsoft Graph 解決結果を比較する read-only action です。差分があっても保存済み値は自動更新せず、差分 field label と一致 field label の summary を読み返してから編集保存へ回します

この runbook は current `main` の Google Drive 運用を正本にしつつ、SharePoint / OneDrive では何が `今できること` かを maintainer が誤読しないよう補っています。

## 10. 関連文書

- [preview 接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
- [Google Drive外部フォルダ同期](./Google%20Drive%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md)
- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md)
- [README](../README.md)
- [docs/README](./README.md)