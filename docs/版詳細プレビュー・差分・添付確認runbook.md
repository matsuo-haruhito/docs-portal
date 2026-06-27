# 版詳細プレビュー・差分・添付確認 runbook

この文書は issue `#718` に対応する、`DocumentVersion` 詳細画面の見方メモです。

current 実装の版詳細画面は、HTML本文、比較対象版との差分、workspace ナビゲーション、添付・元ファイル、品質チェックへの入口を 1 画面に集めた確認ハブです。この runbook では新しい運用ルールは足さず、今の UI で何をどこから見るかだけを整理します。

## 1. 先に見るもの

1. 画面責務の正本は [閲覧画面とUI](./specs/閲覧画面とUI.md)
2. 文書の公開モデルと版の前提は [アプリケーション仕様](./アプリケーション仕様.md)
3. 文書ショートカットや確認依頼との役割差は [ダッシュボードと文書ショートカット・確認依頼の使い分け](./ダッシュボードと文書ショートカット・確認依頼の使い分け.md)
4. Office preview や Microsoft Graph の前提を見直したいときは [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)

## 2. この画面で最初に見る場所

版詳細画面の先頭には、次の 3 つの summary card があります。

- `比較対象`: 今見ている版と、比較に使っている別版を確認する
- `変更サマリ`: 追加・変更・削除の件数を見て、差分確認が必要な大きさかをざっくり判断する
- `プレビュー状態`: HTML本文が開けるか、まだ生成中か、未生成かを確認する

迷ったときの最短順は次です。

1. `プレビュー状態` で HTML本文の状態を見る
2. `比較対象` で、何と比べているかを確認する
3. `変更サマリ` で差分件数を見て、本文差分を見るか、添付・元ファイルを見るかを決める

## 3. 先頭 action の使い分け

画面先頭の action は、今すぐ開きたい確認先に直接飛ぶための入口です。

- `HTML本文を開く`: 生成済み HTML があるときに、公開側の本文表示を開く
- `Docusaurusプレビュー生成中`: Markdown 系ソースで HTML がまだ生成されていないときの表示。しばらくして再読み込みする
- `HTML未生成`: まだ HTML本文を開けない状態。差分や添付・元ファイル確認を先に進める
- `添付・元ファイル`: 添付一覧と元ファイルの分類表示へ移動する
- `左右確認`: 添付・元ファイルの左右比較セクションへ移動する。比較対象版がないときは `左右確認（比較対象なし）` と表示される
- `品質チェック`: internal user だけが使える導線。外部利用者向けの通常導線ではない

補足:

- `HTML本文を開く` がないときでも、版詳細画面の中で元ファイル数、差分件数、添付一覧は先に確認できます
- `HTML本文を開く` から進む viewer shell は、Rails 側の header / breadcrumb / action を持ち、本文は同一 origin の iframe として読み込みます
- viewer shell は iframe 本文の高さに追従します。画像や遅延コンテンツの読み込みで本文が後から伸びる場合は、少し待つか再読み込みしてから、`プレビュー状態` の build 状態と viewer shell 側の表示を切り分けます
- viewer shell の `見出し` は、same-origin iframe 内の `h1` から `h3` までを読み取れる場合だけ本文内移動ボタンとして表示します。見出しがない場合は `見出しはありません`、iframe document を読めない場合は `見出しを取得できませんでした` と読みます
- 見出し導線は最大 24 件までの移動補助です。browser native search、table 内検索、codeblock toolbar、全文検索 index、server-side search の代替ではありません
- Markdown preview iframe 内では `文書内検索 /` の補助 UI を使って、表示中の本文テキストを同一 iframe 内で検索できます。`/` で開き、2文字以上の query で `N件` を表示し、`前へ` / `次へ` または検索欄で Enter / Shift+Enter を使って一致箇所を移動します。`クリア` または Escape で検索状態を戻せます
- Markdown preview document search は、表示済み iframe 本文の目視確認補助です。script / style / nav / footer / aside / 検索 bar 自身は検索対象外で、table 内検索、codeblock toolbar、全文検索 index、server-side search、権限外コンテンツの探索の代替ではありません
- 二重スクロールが常態化して本文末尾まで追いにくい場合は、HTML生成そのものの失敗ではなく、viewer shell と埋め込み本文の高さ追従が怪しい状態として扱い、build warning、生成HTMLの有無、対象 browser で再現するかを確認します
- `品質チェック` は internal user 専用なので、社外向け説明の前提にはしません

### 手動アップロード版の操作 card

手動アップロード由来の版では、internal user だけに `アップロード候補の確認` または `アップロード後の確認` card が出ます。これは社外利用者向けの通常確認導線ではなく、手動アップロード候補を最新版へ反映するか、反映済みの最新版を取り消すための保守導線です。

- `アップロード候補の確認`: `draft` の手動アップロード候補版だけに出る。差分・添付・元ファイルを確認して問題なければ `OK：この内容を反映`、問題があれば `NG：この候補を破棄` を使う
- `OK：この内容を反映`: 候補版を `published` にし、その文書の latest version として扱う。正式承認 workflow、通知、理由入力を追加する操作ではない
- `NG：この候補を破棄`: 候補版を `archived` にする。公開済み版がまだない文書では、文書自体も archive 側に戻ることがある
- `アップロード後の確認`: 反映済みの手動アップロード版が、その文書の latest version のときだけ出る
- `このアップロードを取り消す`: latest の手動アップロード版だけを archive し、直前の published 版があればそこへ戻す。戻せる published 版がない場合は document の latest version が空になり、文書も archive 側に戻る
- `文書一覧へ戻る`: manual upload の source directory を保ったまま、文書一覧へ戻って周辺の候補や反映後の一覧状態を確認する

複数ファイルを drop したときは、すぐに upload や候補版作成へ進まず、drop area 近くの inline preview に件数と先頭 3 件までの file name、上限超過時の `ほかN件` が表示されます。この cue は誤 drop 時に 1 ファイルずつ進める判断へ戻すための補助であり、一括 upload、ZIP import、background job、正式 review workflow ではありません。preview では file content、raw local path、size、type、lastModified、secret-like metadata を確認対象にしません。

確認観点:

- `OK` / `NG` / `このアップロードを取り消す` は internal user 用の保守操作で、download 権限や社外利用者向けの閲覧導線とは別に扱う
- `NG` と `取り消す` はどちらも候補または latest 版を archive するが、`NG` は draft 候補、`取り消す` は反映済み latest manual upload 版に対する操作として読み分ける
- 複数ファイル drop の inline preview は no-submit の確認補助として読み、実行する場合は current single-file upload flow に戻す
- 操作理由、差し戻し理由、通知、正式な approval workflow は current support として書かない。必要な判断は、差分・添付・元ファイル・品質チェックの既存導線で先に確認する

## 4. workspace ナビゲーションの読み方

`版詳細ワークスペース` 直下のナビゲーションは、current main では `差分`、`左右確認`、`添付・元ファイル`、`版情報` の 4 tabs として表示されます。HTML本文や品質チェックなど、版詳細 tab panel そのものではない導線は secondary link として残ります。

- `差分`: `#version-diff` の tab。Markdown本文の行単位diff、HTML差分、表セル差分をまとめて確認する入口
- `左右確認`: `#side-by-side-file-review` の tab。比較対象版と表示中の版の元ファイルを左右で見比べる入口
- `添付・元ファイル`: `#version-files` の tab。添付一覧、元ファイル分類、file browser、個別 preview / download へ進む入口
- `版情報`: `#version-info` の tab。版詳細ワークスペース内で差分・左右確認・添付一覧とは別に置かれる版情報を確認する入口

hash と deep link の読み方:

- `#version-diff` は `差分` tab を開く
- `#markdown-line-diff`、`#html-rendered-diff`、`#html-table-cell-diff` も `差分` tab に正規化される。古い deep link や diff 内 anchor から入っても、まず差分本文の tab を開くと読む
- `#side-by-side-file-review` は `左右確認` tab、`#version-files` は `添付・元ファイル` tab、`#version-info` は `版情報` tab を開く
- hash がない、または上記以外の hash で入った場合は `差分` tab が初期表示になる

確認観点:

- tabs は `role="tablist"` / `role="tab"` / `role="tabpanel"` と `aria-controls` / `aria-selected` で対応づけられる
- keyboard では左右 / 上下 arrow で隣の tab、Home / End で先頭 / 末尾、Enter / Space で選択 tab を開く
- secondary link は tab panel の切り替えではなく、HTML本文や品質チェックなど別の導線として扱う
- #1704 のような runtime migration が未mergeの間は、この runbook では current `app/frontend/controllers/document_version_tabs.js` の挙動だけを正本にする

使いどころ:

- 版詳細画面の中で、差分、左右確認、添付・元ファイル、版情報のどこを今見ているかを見失いたくないとき
- 既存の diff anchor や deep link から入ったときに、どの tab が開くかを誤読したくないとき
- HTML本文や品質チェックの導線を、版詳細 tabs と同じ種類の切り替えだと誤読したくないとき

`HTML本文を開く` から入る standalone viewer では、Markdown table の first slice として real HTML `<table>` ごとに stable key と wrapper metadata が付いています。これは後続の table UX 拡張へつなぐ seam であり、現時点では full `rails_table_preferences` UI、保存済み幅調整、sticky row / column、`embedded=1` body 側の同等 metadata までは前提にしません。broad な follow-up は issue `#475` を正本として見てください。

広い Markdown table では、折りたたみ状態の `表ツール` summary に `横スクロール・列幅調整できます` cue が表示されます。表本体は横スクロール領域として読めるよう `aria-label` を持ち、必要に応じて table 内検索、列幅調整、ヘッダー固定、先頭列固定を current fallback path の範囲で使います。これは表示中 table を読みやすくする補助であり、column visibility、preset UI、full `rails_table_preferences` controller 接続、Docusaurus renderer rewrite が実装済みという意味ではありません。

### Markdown codeblock toolbar の使い方

`HTML本文を開く` から Markdown preview を standalone viewer で開くと、codeblock の右上に補助 toolbar が出ることがあります。

- language badge: `json` など、codeblock class から読み取れる言語を確認する。判定できない場合は `code` と表示される
- `コピー`: 表示中の codeblock 本文を clipboard にコピーする。行番号 anchor が付いている場合でも、コピー対象はコード本文です
- `JSON整形コピー`: `json` と判定された codeblock だけに出る。JSON として parse できる場合は 2 space indent に整形してコピーする
- `JSON検証`: `json` と判定された codeblock だけに出る。parse できれば `JSON OK`、できなければ error message を status に出す
- `機密注意`: `secret`、`token`、`password`、`authorization`、`api key` などの keyword を含む codeblock で出る補助 cue。権限判定、公開可否、security scan、DLP、secret redaction の結果ではない
- 行番号: 複数行の codeblock では行番号から `#codeblock-N-LM` の deep link を作れる。レビューや問い合わせで行を指す補助として使い、正式な承認 workflow や監査ログとしては扱わない

使いどころ:

- Markdown preview 内の JSON 設定例や metadata 断片を、整形して確認・共有したいとき
- JSON の構文だけを軽く確認し、parse error の位置や内容を切り分けたいとき
- 機密らしい keyword が含まれる codeblock を、公開範囲や権限判断とは別に人手確認へ回したいとき
- レビューコメントや問い合わせで、本文 preview の codeblock 行を短い deep link として指したいとき

## 5. `プレビュー状態` の読み方

`プレビュー状態` card では、本文確認をどこから始めるべきかを決めます。

- `HTML本文: 表示可能`: 生成済み HTML があるので、本文確認を先に進めてよい状態
- `HTML本文: Docusaurusプレビュー生成中`: Solid Queue で生成中。元ファイルや差分確認を先に進め、あとで再読み込みする
- `HTML本文: 未生成`: HTML preview を前提にせず、添付・元ファイル、差分、品質チェック中心で確認する
- `ビルド状態`: `PreviewBuildStatusPresenter` が出している current build status をそのまま読む
- `Markdown入口`: build 対象の入口 path。設定がないときは `未設定`
- `元ファイル`: 今の版に紐づく `DocumentFile` 件数
- `ビルドマニフェスト` / `マニフェスト警告`: build manifest がある版だけ表示される

使いどころ:

- まず本文を目で確認できる状態かを知りたいとき
- build warning や detail line が出ていて、preview より先に build 側の異常を疑いたいとき
- HTML 生成待ちの間に、何を先に見ればよいかを決めたいとき

## 6. `比較対象` と `変更サマリ` の読み方

### `比較対象`

- 左側の pill が比較対象版、右側の pill が表示中の版
- `比較対象版を選択` で、どの公開済み版と比べるかを切り替えられる
- `比較できる他の版はありません。` と出るときは、別版との比較を前提にせず、この版単体の確認になる

### `変更サマリ`

- `変更` `追加` `削除` は、添付・元ファイル単位の差分件数をざっくり見るための数
- `差分本文へ移動`: Markdown本文差分、HTML差分、表セル差分の入口
- `左右確認`: ファイルごとの左右比較を見たいときの入口
- `添付・元ファイルへ移動`: 差分より先に現物一覧を見たいときの入口

補足:

- 比較対象版がないときは、画面内でも「左右比較や差分表示は行わず、元ファイル確認が中心」と案内される
- 差分件数が大きいときでも、まず `変更サマリ` で粒度を見てから、必要なセクションだけを開くと追いやすい

## 7. 差分本文と `左右確認` の使い分け

`版差分ビュー` では、比較対象版と表示中の版の差分をまとめて確認できます。

- `Markdown本文の行単位diff`: `.md` / `.markdown` 系の元ファイル差分を、統合diffまたは左右diffで確認する
- `HTML差分`: 生成済み HTML から本文に近い差分を確認する
- `表セル差分`: HTML table の追加・削除・セル変更を確認する
- `左右確認`: 添付・元ファイルを並べて確認したいときの入口

使い分けの目安:

- Markdown 原文の文言差を追いたい: `Markdown本文の行単位diff`
- 実際の表示結果に近い差を見たい: `HTML差分`
- 表だけ重点的に見たい: `表セル差分`
- 添付 PDF や Office file、元ファイル全体を左右で見比べたい: `左右確認`

補足:

- 比較対象版がないときは、差分表示より添付・元ファイル確認が中心になります
- 大きすぎるファイルや読み込めないファイルでは、差分の代わりに理由メッセージが出ることがあります

## 8. `添付・元ファイル` の見方

`添付・元ファイル` セクションでは、今の版に紐づくファイルを分類つきで確認できます。

- `通常確認ファイル`: まず日常確認で見るファイル
- `グループ: ...`: metadata でまとめられたファイル群
- `補助ファイル`: 通常確認対象からは外している内部資料や補助ファイル
- `デバッグ用ファイル`: レンダリング確認や調査用のファイル
- `その他のファイル`: 上の分類に入らないファイル

セクション上部の file browser では、表示中のファイルを file name / tree path / group name ベースで絞り込めます。

- 検索欄: `README / attachments/spec.pdf / diagrams` のような語で絞り込む
- 分類ボタン: `すべて` `通常` `グループ` `補助` `デバッグ` `その他` のどこを見るかを切り替える
- 件数表示: `N件を表示中` と、いまの検索語や分類を表示する。検索語と分類 filter を併用している場合は `検索: ... / 分類: ...` のように両方が並ぶ
- `検索条件に一致するファイルはありません。`: 検索語で 0 件になった状態。検索語を短くする、file name / tree path / group name の別表記を試す
- `選択した分類に一致するファイルはありません。`: 分類 filter だけで 0 件になった状態。`すべて` に戻して、通常 / グループ / 補助 / デバッグ / その他のどこに対象があるかを見直す
- `検索条件と分類の両方に一致するファイルはありません。`: 検索語と分類 filter の両方が効いて 0 件になった状態。まず検索語または分類のどちらかを外して切り分ける

補足:

- grouped section は `グループ名` でも検索に掛かるので、資料群のまとまりから探したいときに使えます
- metadata がない版では分類ボタンは出ず、単一 list のまま検索だけ使えます。その場合、分類 filter 由来の empty state ではなく検索語だけの 0 件として読みます
- file browser は表示済み行の client-side 絞り込みだけなので、権限外ファイルを追加で露出するものではありません

このセクションを先に見る場面:

- HTML が未生成でも、元ファイルや添付構成だけ先に確認したいとき
- `変更サマリ` で件数だけ見ても、どのファイルが対象か分からないとき
- 補助資料や debug 用ファイルが混ざっていないかを確認したいとき
- ファイル数が多く、通常確認ファイルや特定グループへ目視走査なしで辿りたいとき

## 9. 個別 `DocumentFile` preview の見方

添付一覧や ZIP 内ファイル一覧から個別 file を開くときは、`DocumentFileViewerPlan` が判定した viewer kind に応じて inline preview または download に進みます。ここでは新しい viewer 方針を定義せず、current implementation で画面に出る確認観点だけを扱います。種別ごとの方針正本は [閲覧画面とUI](./specs/閲覧画面とUI.md) の `DocumentFile viewer registry` を見ます。

### 入る前に見ること

- 添付一覧の分類、file name、tree path、group name で、確認対象の file が通常確認対象か補助 / debug file かを見分ける
- `プレビュー` に進める file でも、download 権限やウイルススキャン状態によって download / preview の可否は分かれる
- preview できない場合は、画面上の理由表示と download 導線を確認し、runbook 側で未実装 viewer を実装済み扱いしない

### mode 別の確認観点

| mode | 見る場所 | 何を確認するか |
| --- | --- | --- |
| PDF / image | inline preview | PDF や画像がブラウザ上で開けるか、必要なら file name と download 導線を確認する |
| CSV / TSV | `CSV / TSV preview` | sample 行、表内検索、表示中行の CSV copy、先頭行 / 先頭列固定、列幅 reset を確認する。大きい file は先頭行だけの preview になり、全件確認は download に戻す |
| JSON / YAML | `JSON preview` / `YAML preview` | parse 後の整形表示、検索、一致行のみ表示、整形済み内容 copy を確認する。parse できないときは error card の理由を見る |
| Text / log | `テキスト内検索` | 行番号付きの先頭行 preview、検索、一致行のみ表示、copy を確認する。truncated 表示があるときは全文確認を download に戻す |
| ZIP | `ZIP内サマリー` / `ZIP内ファイル一覧` | file / folder 件数、directory summary、検索 / filter / sort、要注意 path、text preview 候補、個別 download 候補を確認する。大きい ZIP は先頭項目だけの preview になる |
| Office | Microsoft Graph preview | embedded preview では Graph preview へ redirect する。250MB 超などで preview 不可の場合は `Officeプレビュー不可` 画面で file name、size、download 可否を確認する |
| ZIP 以外の archive | download only | `ZIP以外の圧縮ファイル preview は未対応です` の理由表示を確認し、必要なら download で扱う |
| unknown binary / unsupported | download only | `ブラウザ preview は未対応です` の理由表示と download 可否を確認する |

### PDF / image preview の操作補助

PDF / image の inline preview では、画面上の button 操作に加えて、current helper が visible shortcut cue、keyboard shortcut、browser localStorage による表示状態保存を持っています。入力欄、textarea、select、contenteditable に focus があるときや、Ctrl / Alt / Meta と組み合わせた key は邪魔しません。

- PDF preview の visible cue: status の直後に `ショートカット: h / Hで高さ切替。表示高さはこのブラウザに保存されます。` と表示されます。`h` / `H` は `大きく表示` と `標準高さに戻す` の切り替えで、button の `title` / `aria-label` も同じ操作を指す補助ラベルです
- PDF preview の状態: 高さ表示は browser の localStorage に保存されます。次回同じ preview を開いたときの見え方を補助するだけで、PDF file 自体、download 可否、権限、server 側共有設定は変わりません
- image preview の visible cue: status の直後に `ショートカット: + / - 拡大縮小、0 リセット、F 画面幅、[ / ] 回転。表示はこのブラウザに保存されます。` と表示されます
- image preview の操作: `+` / `=` で拡大、`-` / `_` で縮小、`0` で倍率 reset、`f` / `F` で `画面に合わせる` と倍率表示を切り替える、`[` / `]` で左右に 90 度ずつ回転します。拡大・縮小・倍率 reset・fit toggle・左右回転 button の `title` / `aria-label` は、visible cue と同じ操作を指す補助ラベルとして読みます
- image preview の状態: `fit` / `zoom` / `rotation` は browser の localStorage に保存されます。端末・browser・対象 preview ごとの補助状態として扱い、共有設定、server 側表示設定、file 本体、download 可否、権限とは読まない

この節は current `image_preview_tools.js` / `pdf_preview_tools.js` の既存 support だけを説明します。shortcut の新規追加、localStorage key / 保存形式の変更、visual regression、PDF / image renderer の変更、Office / ZIP / CSV / JSON preview への横展開は別 issue の判断に残します。

### preview と download の切り分け

- `embedded=1` の file preview は版詳細の閲覧権限と scan 状態を満たす file だけを対象にする
- 直接 download 導線では `DocumentFile` の download 権限を見て、inline preview と同じ前提にしない
- Office preview の接続や folder 設定を疑うときは [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) と [Microsoft Graph接続管理runbook](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E7%AE%A1%E7%90%86runbook.md) を先に見る
- ZIP 内 entry の個別 preview / download は [ZIPプレビューと個別ダウンロード確認 runbook](./ZIP%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E5%80%8B%E5%88%A5%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E7%A2%BA%E8%AA%8Drunbook.md) も合わせて確認する

## 10. `品質チェック` を見る場面

`品質チェック` は internal user だけの導線です。次のような場面で使います。

- HTML preview が未生成または warning 付きで、build 周りの異常を詳しく追いたいとき
- 添付・元ファイルや metadata の分類だけでは原因を絞れないとき
- 公開前に、表示以前の整合性チェックを見たいとき

社外利用者向けの本文確認や添付確認では、この導線を前提にしません。

## 11. 迷ったときの切り分け

- 本文がすぐ見られるか知りたい: `プレビュー状態`
- 何と比べているかを知りたい: `比較対象`
- 差分が大きいかだけ先に見たい: `変更サマリ`
- 実際の表示結果に近い差を見たい: `HTML差分`
- Markdown 原文の差を見たい: `Markdown本文の行単位diff`
- 表だけ見たい: `表セル差分`
- HTML本文の広い Markdown table を読みたい: `HTML本文を開く` 後の `表ツール` summary で横スクロール・列幅調整 cue を確認し、必要に応じて table 内検索や列幅調整を使います。full `rails_table_preferences` UI や preset UI とは読み分けます
- 添付や元ファイルの現物を整理して見たい: `添付・元ファイル`
- ファイル名やグループ名から素早く対象を絞りたい: `添付・元ファイル` 上部の file browser
- 個別 file の preview mode と fallback を知りたい: 個別 `DocumentFile` preview
- ZIP 内 entry の summary、filter、個別 preview / download を見たい: [ZIPプレビューと個別ダウンロード確認 runbook](./ZIP%E3%83%97%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E5%80%8B%E5%88%A5%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E7%A2%BA%E8%AA%8Drunbook.md)
- 手動アップロード候補を反映・破棄・取り消しするか迷う: `アップロード候補の確認` / `アップロード後の確認` card の対象版、latest かどうか、直前の published 版の有無を確認する
- 複数ファイルを誤って drop した: inline preview の件数と代表 file name だけを確認し、一括 upload ではなく 1 ファイルずつ進める current flow に戻す
- HTML本文の章立てから移動したい: `HTML本文を開く` 後の viewer shell で `見出し` を見ます。見出しがない、または iframe document を読めない場合は、本文側の通常スクロールや browser native search に戻します
- HTML本文内の語句を iframe 内で探したい: Markdown preview の `文書内検索 /` を開き、2文字以上で検索します。table 内検索、codeblock toolbar、全文検索 index、server-side search とは別の、表示中本文だけの確認補助として扱います
- HTML本文で二重スクロールや高さずれが続く: `HTML本文を開く` 後の viewer shell と埋め込み本文の高さ追従を疑い、build 状態、生成HTMLの有無、再読み込み後の再現性を確認する
- build や metadata の異常を internal 観点で追いたい: `品質チェック`

## 12. 関連画面

- `app/views/document_versions/show.html.slim`
- `app/views/document_versions/_rollback_actions.html.slim`
- `app/services/manual_document_upload_review.rb`
- `app/services/document_version_rollback.rb`
- `app/frontend/controllers/document_version_tabs.js`
- `app/views/shared/site_viewer.html.slim`
- `app/frontend/lib/site_viewer_heading_outline.js`
- `app/frontend/controllers/site_viewer_iframe_height_controller.js`
- `app/frontend/lib/markdown_preview_codeblock_tools.js`
- `app/frontend/lib/markdown_preview_document_search.js`
- `app/frontend/controllers/markdown_preview_document_search_controller.js`
- `app/frontend/lib/image_preview_tools.js`
- `app/frontend/lib/pdf_preview_tools.js`
- `app/views/document_files/show_pdf_preview.html.slim`
- `app/views/document_files/show_image_preview.html.slim`
- `app/views/document_files/show_csv_preview.html.slim`
- `app/views/document_files/show_structured_preview.html.slim`
- `app/views/document_files/show_archive_preview.html.slim`
- `app/views/document_files/show_text_preview.html.slim`
- `app/views/document_files/office_preview_unavailable.html.slim`
- `app/views/documents/_detail_sections.html.slim`
- `app/views/documents/_tree.html.erb`
- `app/views/documents/_comment_workspace.html.slim`
