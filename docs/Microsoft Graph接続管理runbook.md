# Microsoft Graph接続管理runbook

この runbook は、管理画面 `admin/microsoft_graph_connections` で案件ごとの Office preview 接続を日常運用で見直すときの読み順をまとめたものです。接続前提や fallback の仕様そのものは [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を正本とし、この文書では current UI 上で何を確認するかに絞ります。

## まず見る画面

- 管理画面のメニューから `Microsoft Graph接続` を開きます。
- 一覧では `案件 / 接続名 / Tenant / Client / Site / Drive / プレビュー用フォルダ / 状態 / preview利用 / 操作` をまとめて見返せます。
- 一覧の手前には `Microsoft Graph接続一覧の表示設定` があり、列の表示や幅をこの一覧専用の table preferences として調整できます。
- `Drive` 列では `主確認: Drive ID` を読みます。`Site ID` は `Tenant / Client / Site` 列の補助値として、Drive ID の取得元を追跡したいときに見ます。
- `Tenant / Client / Site` 列の `Tenant ID` / `Client ID` / `Site ID` は補助値、`プレビュー用フォルダ` 列の `プレビュー用フォルダ` は preview 不達時の主確認値として読みます。
- 同じ画面の下側で新規登録、各行の `編集` から既存設定の更新、`削除` から不要設定の除去を行います。
- 同一案件に複数の有効接続が残っている場合は、一覧上部に `preview 利用中の接続を要整理の案件` card が出ます。
- 一覧上部の `一覧の絞り込み` では、`previewで使用中` `有効だが未使用` `無効 / previewでは未使用` `要整理案件のみ` に切り替えて確認できます。
- 同じ `一覧の絞り込み` の検索欄では、案件名・案件 code・接続名・Tenant ID / Client ID・Drive ID / Site ID・プレビュー用フォルダで対象接続を絞り込めます。
- 検索欄の入力上限と直下の補足 copy も同じ最大 100 文字境界を示します。検索対象を迷ったときは、入力欄直下の `検索対象: 案件名・code・接続名・Tenant / Client / Drive / Site ID・プレビュー用フォルダ（最大100文字）` を最初に確認します。
- 検索語は前後空白を除いて単語間空白を詰めたあと、最大 100 文字までが条件に使われます。長い ID やフォルダ path 全文ではなく、案件 code、接続名、Drive ID、Site ID、フォルダ名の特徴的な短い断片で探します。
- 一覧 table は 1 ページ最大 50 行まで表示します。`表示範囲: X-Y件 / 条件一致 N件` は、現在の検索語・preview 利用 filter・要整理 filter を適用した総件数と、現在ページの範囲を分けて読むための summary です。
- summary 内の `A / B 件を表示しています` は、現在ページの表示行数と接続全体件数を並べた補助表示です。filter link の件数は全体集計で、現在ページの件数や検索語適用後の件数とは役割が違います。
- `前の50件` / `次の50件` は、現在の検索語、preview 利用状態、要整理案件 filter を保ったままページを移動します。ページ移動は接続選択ロジック、Graph credential、Office preview runtime、外部フォルダ同期本体を変更する操作ではありません。
- 無効な `page` や範囲外の `page` は 1 ページ目へ戻ります。ページ指定の異常を、接続削除や filter 条件の不一致とは読まないでください。
- まだ接続が 0 件のときは一覧 table は表示されず、上部の `新規登録` form と empty state だけが出ます。最初の 1 件を作るときは `案件`、`接続名`、`Tenant ID`、`Client ID`、`Drive ID`、`プレビュー用フォルダ` を埋めます。SharePoint / OneDrive の共有フォルダ URL が分かる場合は、保存前に `共有URLから候補を取得（保存しない）` で `Drive ID` と `プレビュー用フォルダ` の候補をフォームへ戻せます。この取得操作は接続設定を保存しないため、候補を確認してから別途 `保存` を押します。
- 新規登録・編集 form の `案件` は `案件コード・案件名で検索` する remote combobox です。全件 select ではないため、案件 code や案件名の短い断片で候補を呼び出して選びます。
- 案件候補は `案件code / 案件名` の label で表示され、検索結果は最大 20 件です。保存済みの案件は、編集時や validation error 後の再表示でも selected option として復元されます。

## 日常確認の順番

1. 一覧上部に `preview 利用中の接続を要整理の案件` card が出ていないか確認する
2. 対象が多いときは `一覧の絞り込み` で `previewで使用中` `有効だが未使用` `無効 / previewでは未使用` `要整理案件のみ` を切り替え、必要なら検索欄で案件名・code・接続名・Drive 情報を絞る
3. 日常 triage で列が見づらいときは `Microsoft Graph接続一覧の表示設定` で列幅や表示列を調整し、`案件` と `操作` が固定列として残ることを確認する
4. 対象案件に対して、`preview利用` 列で `previewで使用中` の行がどれかを見る
5. `状態` が `有効` になっているかを見る
6. `Drive` 列の `主確認: Drive ID` と、`プレビュー用フォルダ` 列の `主確認: プレビュー用フォルダ` が想定どおりか確認する
7. 必要に応じて `Tenant / Client / Site` 列の補助値を見て、別テナント・別アプリ・別 site の値が混ざっていないか確認する
8. Office preview が開かないときは、この文書の `preview 不達時の戻り先` へ進む

## 検索と絞り込みの併用

- 検索欄は `previewで使用中` / `有効だが未使用` / `無効 / previewでは未使用` / `要整理案件のみ` の filter と併用できます。
- 検索語は `squish` 後の最大 100 文字までが使われます。blank や空白だけの入力は active filter に残りません。
- 検索 input には同じ 100 文字上限が `maxlength` として設定され、入力欄直下に検索対象と最大文字数の cue が表示されます。cue は検索対象を広げる仕様ではなく、DB 側検索境界と同じ読み方を画面上で確認するための補助です。
- 検索は DB 側で、案件名・案件 code・接続名・Tenant ID / Client ID・Drive ID / Site ID・プレビュー用フォルダを対象に部分一致します。preview runtime の接続選択や共有 URL 解決の保存 contract は変えません。
- 接続数が多いときは、まず preview 利用状態や `要整理案件のみ` で候補を狭めてから、案件名・code・接続名・Drive ID / Site ID・プレビュー用フォルダで検索します。
- 表示される行は 1 ページ最大 50 件です。50 件を超える場合は、現在ページだけで全件を判断せず、`前の50件` / `次の50件` で同じ条件のまま読み進めます。対象が多すぎるときは検索語や preview 利用 filter を追加して候補を狭めます。
- `表示範囲: X-Y件 / 条件一致 N件` は、現在の検索語と filter を適用した結果のうち、いま見ているページ範囲を示します。`1ページ目 / 50件上限` などの page 表示もあわせて確認します。
- filter link の `すべて` `previewで使用中` `有効だが未使用` `無効 / previewでは未使用` の件数は、現在の検索語やページとは独立した全体集計です。現在の table 件数と条件一致件数は table 上部の表示範囲 summary で確認します。
- `前の50件` / `次の50件` は、検索語、preview 利用状態、要整理案件 filter を保持します。ページ移動後も `現在の絞り込み` を見て、意図した条件のまま読んでいるか確認します。
- filter link を切り替えても検索語は保持されます。検索だけを外したいときは `検索を解除`、filter も含めて戻すときは `絞り込みを解除` を使います。
- 一覧 0 件は、未登録とは限りません。登録済み接続がある状態で 0 件なら、検索語や filter が強すぎないかを先に見直します。
- 登録済み接続があるのに current filter で 0 件になった場合、画面には `現在の絞り込みに一致する Microsoft Graph接続はありません。` と `検索と絞り込みを解除` の button-style action が出ます。未登録 0 件の `まだMicrosoft Graph接続は登録されていません。` とは分けて読みます。
- `検索と絞り込みを解除` は検索語、preview 利用 filter、要整理案件 filter を外して全体表示へ戻るための復帰導線です。preview 接続の正常保証、Graph 接続の修復、共有URL解決、Office preview 成功を意味しません。
- `Drive ID` や `プレビュー用フォルダ` の typo、旧接続名、別テナントの `Tenant / Client` が疑わしいときは、検索で該当値を直接探してから `編集` で詳細を確認します。
- この検索は current UI の一覧切り分け用です。Office preview runtime、接続の自動選択、SharePoint / OneDrive 同期本体の仕様は変更しません。

## 表示設定と列の読み方

- `Microsoft Graph接続一覧の表示設定` は、この一覧の列表示を Rails Table Preferences の既存 pattern で調整するための入口です。列の表示 / 非表示や幅を変えても、接続の保存値、preview 利用判定、検索対象、filter count は変わりません。
- current 列 key は `案件`、`接続名`、`Tenant / Client / Site`、`Drive`、`プレビュー用フォルダ`、`状態`、`preview利用`、`操作` です。
- `案件` と `操作` は固定列です。対象案件と `編集` / `削除` / `外部フォルダ同期設定を確認` への戻り先を失わないため、日常 triage でも最後に見える状態を保ちます。
- `Tenant / Client / Site` は補助 identifier をまとめた列、`Drive` と `プレビュー用フォルダ` は preview 不達時の主確認列です。Drive ID と preview folder を一時的に隠したまま運用判断を完了しないでください。
- 一覧の identifier は短縮・mask 済みの確認値です。raw 値の照合や修正が必要な場合は、対象行の `編集` で確認します。
- 表示設定は一覧を見やすくするための補助であり、Microsoft Graph 接続の選択ロジック、共有 URL 解決、外部フォルダ同期 dry-run / apply、SharePoint / OneDrive 同期本体を変更するものではありません。

## 接続が 0 件のとき

- empty state は異常ではなく、まだ preview 用接続が未登録な状態です
- この状態では一覧性より初回登録導線が優先されるので、上部 `新規登録` form をそのまま入口にします
- 検索語や preview 利用 filter を指定した状態で 0 件になり、`検索と絞り込みを解除` が出ている場合は、未登録ではなく filtered 0 件の状態です。条件を外して全体表示へ戻り、登録済み接続の有無を見直します
- `案件` は案件コード・案件名の remote search で選びます。接続が 0 件でも案件一覧を全件表示する select ではないため、まず案件 code や案件名の短い断片で候補を出します
- `Tenant ID`、`Client ID`、`Drive ID`、`プレビュー用フォルダ` がそろわない段階では保存を急がず、先に接続前提や案件の保存先方針を確認します
- SharePoint / OneDrive の共有フォルダ URL を管理者が持っている場合は、先に `共有フォルダURL` を入力し、`共有URLから候補を取得（保存しない）` で入力補助を試します。候補取得はフォーム反映だけで、接続設定の保存や credential 検証完了を意味しません
- 同一案件で有効にできる Microsoft Graph 接続は 1 件だけです。切り替えたい場合は、現在の有効接続を先に無効化してから保存します

## フォームの案件選択 remote search

- 新規登録・編集 form の `案件` は RFK の remote combobox です。placeholder は `案件コード・案件名で検索` で、検索対象は案件 code と案件名です。
- 候補 label は `案件code / 案件名` です。外部フォルダ同期設定の案件選択と同じ読み方で、接続名や Drive ID ではなく、接続を紐づける案件そのものを選びます。
- 案件検索語は前後空白を除いたあと最大 100 文字までが使われ、候補は最大 20 件です。大量案件から探すときは、案件 code、案件名の特徴的な短い断片で絞ります。
- 20 件の候補 window に入らない保存済み案件でも、編集時は `selected_project` 経由で selected option として復元されます。候補一覧に出ないだけで保存済み値が失われたとは判断しません。
- validation error で form が再表示された場合も、選択済み案件は同じ `案件code / 案件名` label で残ります。接続名や Drive ID などの修正中に、案件が blank に戻っていないかだけ確認します。
- `共有URLから候補を取得（保存しない）` は Drive ID / Site ID / プレビュー用フォルダ候補をフォームに戻す補助です。案件 remote search の保存先を変更する action ではないため、共有 URL 解決後も選択済み案件が意図どおり残っているかを確認してから `保存` します。
- 存在しない案件 ID の selected lookup は option なしとして扱われます。手入力 ID の直接指定、案件の自動作成、外部フォルダ同期 source の再検索、Graph 側の権限設計はこの form の current support ではありません。

## 共有フォルダURLから候補を取得する

`共有URLから候補を取得（保存しない）` は保存処理ではなく、Microsoft Graph の `shares/.../driveItem` からフォーム入力候補を戻すための補助ボタンです。解決に成功すると、フォーム上の `Drive ID`、`Site ID`、`プレビュー用フォルダ` が更新されます。内容を確認してから、別途 `保存` を押して接続設定として登録または更新します。

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

- `Drive` 列には preview 用一時アップロード先の `主確認: Drive ID` が出ます
- `site_id` がある接続では、`Tenant / Client / Site` 列の中に `補助: Site ID` も表示されます。Drive ID の取得元を追跡したいときの補助情報として読みます
- 案件をまたいで同じ値を使うこと自体は current code 上で禁止されていませんが、運用上はどの案件の preview 用保存先かを追えるようにしておく方が安全です
- SharePoint / OneDrive の共有フォルダ URL が正しい場合は、`共有URLから候補を取得（保存しない）` で Graph から `drive_id` と `site_id` の候補を戻せます。候補が戻っただけでは保存されないため、内容を見直してから `保存` します
- preview 先を切り替えた直後は、古い `drive_id` のまま残っていないかを最初に確認します

## `プレビュー用フォルダ` の見直しポイント

- `preview_folder_path` は一覧の `プレビュー用フォルダ` 列で `主確認: プレビュー用フォルダ` として確認できます
- current validation では、空欄、`/` 始まり、`..` を含む相対パスは保存できません
- 初期値は `docs-portal-previews` です。案件ごとに preview 用フォルダを分けている場合は、名前だけでどの用途か分かる状態を保ちます
- `共有URLから候補を取得（保存しない）` に成功した場合は、共有フォルダの `parentReference.path` と folder name から root 相対の候補が入ります。保存前に、preview 用一時アップロード先としてそのフォルダでよいかを確認します
- Office preview が失敗したときは、`drive_id` だけでなく `preview_folder_path` の typo や、意図しないフォルダ名変更も確認します

## 編集時に見る項目

- `案件`: どの案件の Office preview に使う接続か。案件コード・案件名で検索し、`案件code / 案件名` の selected label が意図した案件になっているかを見る
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
3. `主確認: Drive ID` と `主確認: プレビュー用フォルダ` が、実際に使いたい接続の値になっているか、切り替え前の値や typo のある値に戻っていないか確認する。接続数が多いときは検索欄で `drive_id` や folder 名を直接探す
4. 入力値自体が妥当か、`編集` 画面で `Tenant ID` / `Client ID` / `Site ID` も含めて見直す。共有フォルダ URL が分かる場合は、保存前に `共有URLから候補を取得（保存しない）` で候補を取り直し、内容を確認してから `保存` する
5. 接続前提や fallback 条件を確認したい場合は [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) へ戻る
6. 外部フォルダ同期や `.env` 側の責務分担を確認したい場合は [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) へ戻る

## この runbook で扱わないこと

- Azure / Microsoft Graph 側の権限設計そのもの
- preview URL の選択ロジック変更
- model validation や query helper の実装詳細
- SharePoint / OneDrive 同期機能の後続仕様
- 表示設定による接続選択、filter、外部フォルダ同期 workflow の変更

## 関連ドキュメント

- [README](../README.md)
- [docs/README](./README.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
