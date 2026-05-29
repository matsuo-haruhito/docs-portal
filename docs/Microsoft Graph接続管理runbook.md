# Microsoft Graph接続管理runbook

この runbook は、管理画面 `admin/microsoft_graph_connections` で案件ごとの Office preview 接続を日常運用で見直すときの読み順をまとめたものです。接続前提や fallback の仕様そのものは [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を正本とし、この文書では current UI 上で何を確認するかに絞ります。

## まず見る画面

- 管理画面のメニューから `Microsoft Graph接続` を開きます。
- 一覧では `案件 / 接続名 / Tenant / Client / Drive / プレビュー用フォルダ / 状態 / preview利用` をまとめて見返せます。
- 同じ画面の下側で新規登録、各行の `編集` から既存設定の更新、`削除` から不要設定の除去を行います。
- 同一案件に複数の有効接続が残っている場合は、一覧上部に `preview 利用中の接続を要整理の案件` card が出ます。
- 一覧上部の `一覧の絞り込み` では、`previewで使用中` `有効だが未使用` `無効 / previewでは未使用` `要整理案件のみ` に切り替えて確認できます。
- まだ接続が 0 件のときは一覧 table は表示されず、上部の `新規登録` form と empty state だけが出ます。最初の 1 件を作るときは `案件`、`接続名`、`Tenant ID`、`Client ID`、`Drive ID`、`プレビュー用フォルダ` を埋めます。SharePoint / OneDrive の共有フォルダ URL が分かる場合は、保存前に `共有URLからDrive情報を解決` で `Drive ID` と `プレビュー用フォルダ` の候補をフォームへ戻せます。

## 日常確認の順番

1. 一覧上部に `preview 利用中の接続を要整理の案件` card が出ていないか確認する
2. 対象が多いときは `一覧の絞り込み` で `previewで使用中` `有効だが未使用` `無効 / previewでは未使用` `要整理案件のみ` を切り替える
3. 対象案件に対して、`preview利用` 列で `previewで使用中` の行がどれかを見る
4. `状態` が `有効` になっているかを見る
5. `Drive` 列の `drive_id` と、`プレビュー用フォルダ` 列の `preview_folder_path` が想定どおりか確認する
6. 必要に応じて `Tenant / Client` を見て、別テナントや別アプリの値が混ざっていないか確認する
7. Office preview が開かないときは、この文書の `preview 不達時の戻り先` へ進む

## 接続が 0 件のとき

- empty state は異常ではなく、まだ preview 用接続が未登録な状態です
- この状態では一覧性より初回登録導線が優先されるので、上部 `新規登録` form をそのまま入口にします
- `Tenant ID`、`Client ID`、`Drive ID`、`プレビュー用フォルダ` がそろわない段階では保存を急がず、先に接続前提や案件の保存先方針を確認します
- SharePoint / OneDrive の共有フォルダ URL を管理者が持っている場合は、先に `共有フォルダURL` を入力し、`共有URLからDrive情報を解決` で入力補助を試します
- 同一案件で有効にできる Microsoft Graph 接続は 1 件だけです。切り替えたい場合は、現在の有効接続を先に無効化してから保存します

## 共有フォルダURLからDrive情報を解決する

`共有URLからDrive情報を解決` は保存処理ではなく、Microsoft Graph の `shares/.../driveItem` からフォーム入力候補を戻すための補助ボタンです。解決に成功すると、フォーム上の `Drive ID`、`Site ID`、`プレビュー用フォルダ` が更新されます。内容を確認してから、別途 `保存` を押して接続設定として登録または更新します。

新規登録では、`Tenant ID`、`Client ID`、`Client secret`、`共有フォルダURL` を入力してから解決します。編集時は、`Client secret` を空欄のままでも保存済み secret を使って解決できます。secret を差し替えたい場合だけ再入力します。

解決できるのは SharePoint / OneDrive の共有フォルダ URL です。ファイル共有 URL、空欄、HTTP URL として解釈できない値、Graph 側で access token や drive item を取得できない値はエラーとしてフォームに戻ります。エラー時も保存は行われないため、Tenant / Client / secret / URL を見直してから再実行します。

この flow は Office preview 用の一時アップロード先を埋めるための入力補助です。SharePoint / OneDrive との双方向同期、delta 取得、subscription、portal 側から Graph への publish はこの runbook の対象外です。

## `preview利用` 列の読み方

- `previewで使用中`: current preview がこの接続を使います
- `有効だが未使用`: この行も有効ですが、別の有効接続が preview に使われています。legacy duplicate を整理するときの対象です
- `previewでは未使用`: 無効な接続、または preview の対象外の接続です

current `main` では、同一案件で有効にできる接続は新規保存時に 1 件だけです。`有効だが未使用` が見えている場合は、旧データ由来の重複有効接続が残っているので、`previewで使用中` の 1 件だけを残して他を無効化または削除します。

legacy duplicate が残っている案件では、current preview 正本は `preview_selected_ids_by_project` の実装どおり `同一案件の有効接続のうち最小 DB id` で暫定的に決まります。つまり `previewで使用中` は「もっとも妥当な設定を明示選択した結果」ではなく、旧データが残っている間だけの暫定表示です。`#760` で explicit selection に寄せるまでは、この暫定挙動を前提に読みます。

## 複数行が並んでいるときの見方

- 一覧は `name`, `id` 順で並びます
- 新規保存では同一案件の `有効` 接続を 1 件に制限します
- それでも旧データ由来で同一案件に有効行が複数残っている場合は、一覧上部の整理 card と `preview利用` 列を見て、どの行を残すかを判断します
- 整理対象が多いときは `要整理案件のみ` へ切り替え、card 内の案件リンクから対象行へ直接移動します
- ただし current `previewで使用中` は、duplicate がある間だけ `最小 DB id の行` を指している可能性があります。`Drive ID`、`プレビュー用フォルダ`、`Tenant / Client` を見て、実際に preview 正本として残したい設定かを確認してから整理します
- preview の日常運用では、`previewで使用中` の行を 1 件だけ維持し、`有効だが未使用` を放置しない状態に戻します
- DB id が小さい行を機械的に残す運用は current code の暫定挙動を固定化してしまうため避けます。どの接続を残すか迷う場合は、案件担当者が現在使っている preview 接続を確認してから整理します
- `#760` が landed したら、この節の暫定説明も current runtime に合わせて見直します

## `Drive ID` の見直しポイント

- `Drive` 列には preview 用一時アップロード先の `drive_id` が出ます
- 案件をまたいで同じ値を使うこと自体は current code 上で禁止されていませんが、運用上はどの案件の preview 用保存先かを追えるようにしておく方が安全です
- `site_id` は一覧には出ないため、必要なら `編集` 画面で補助メモとして確認します
- SharePoint / OneDrive の共有フォルダ URL が正しい場合は、`共有URLからDrive情報を解決` で Graph から `drive_id` と `site_id` の候補を戻せます
- preview 先を切り替えた直後は、古い `drive_id` のまま残っていないかを最初に確認します

## `プレビュー用フォルダ` の見直しポイント

- `preview_folder_path` は一覧の `プレビュー用フォルダ` 列で確認できます
- current validation では、空欄、`/` 始まり、`..` を含む相対パスは保存できません
- 初期値は `docs-portal-previews` です。案件ごとに preview 用フォルダを分けている場合は、名前だけでどの用途か分かる状態を保ちます
- `共有URLからDrive情報を解決` に成功した場合は、共有フォルダの `parentReference.path` と folder name から root 相対の候補が入ります。保存前に、preview 用一時アップロード先としてそのフォルダでよいかを確認します
- Office preview が失敗したときは、`drive_id` だけでなく `preview_folder_path` の typo や、意図しないフォルダ名変更も確認します

## 編集時に見る項目

- `案件`: どの案件の Office preview に使う接続か
- `接続名`: 一覧で識別しやすい表示名か
- `認証方式`: current code では `client_credentials` のみ
- `Tenant ID` / `Client ID`: 想定するテナントとアプリか
- `Client secret`: 変更時のみ再入力が必要か。共有 URL 解決では、編集時に空欄なら保存済み secret を使います
- `共有フォルダURL`: 保存項目ではなく、Drive ID / Site ID / プレビュー用フォルダ候補を解決するための入力補助か
- `Site ID`: 必須ではないが、Drive ID の取得元を追跡したいときの補助メモ
- `Drive ID`: preview 用一時アップロード先の識別子
- `プレビュー用フォルダ`: 相対パスで安全に保存できる値か
- `状態`: `有効` / `無効` の切り替えが案件運用と一致しているか

フォーム下部にも、`同一案件で有効にできる Microsoft Graph 接続は 1 件だけ` という補足が出ます。切り替え時は、現在の有効接続を先に無効化してから保存してください。

## preview 不達時の戻り先

1. まずこの一覧で、対象案件に `previewで使用中` の行があるか確認する
2. `preview 利用中の接続を要整理の案件` card や `有効だが未使用` 行が出ていないか確認し、重複有効接続がある場合は `最小 DB id` の暫定選択に引きずられていないかを見る
3. `Drive ID` と `プレビュー用フォルダ` が、実際に使いたい接続の値になっているか、切り替え前の値や typo のある値に戻っていないか確認する
4. 入力値自体が妥当か、`編集` 画面で `Tenant ID` / `Client ID` / `Site ID` も含めて見直す。共有フォルダ URL が分かる場合は、保存前に `共有URLからDrive情報を解決` で候補を取り直す
5. 接続前提や fallback 条件を確認したい場合は [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) へ戻る
6. 外部フォルダ同期や `.env` 側の責務分担を確認したい場合は [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) へ戻る

## この runbook で扱わないこと

- Azure / Microsoft Graph 側の権限設計そのもの
- preview URL の選択ロジック変更
- model validation や query helper の実装詳細
- SharePoint / OneDrive 同期機能の後続仕様

## 関連ドキュメント

- [README](../README.md)
- [docs/README](./README.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
