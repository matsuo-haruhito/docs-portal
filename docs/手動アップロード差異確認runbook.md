# 手動アップロード差異確認runbook

この runbook は、internal user が `文書一覧` の `ファイルをアップロード` panel や TreeView / 文書行への drop から手動アップロード候補を作成したあと、`OK` / `NG` を判断するための current flow をまとめる。

新しい upload policy や承認ルールはここでは定義しない。current `DocumentUploadsController#create`、`ManualDocumentUpload`、`DocumentVersionUploadReviewsController#create`、版詳細画面の review action を前提に、「どこへ遷移するか」「既存文書の版更新候補と新規文書候補をどう見分けるか」「反映後にどこから取り消せるか」だけを整理する。

## 先に見るもの

1. project-scoped の一覧、TreeView、upload panel 自体の役割は [文書一覧の検索・実用フィルタ・ZIP出力 runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
2. 版詳細画面の本文・差分・添付・品質チェックの読み方は [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md)
3. 文書の公開モデルや `latest_version` の前提は [アプリケーション仕様](./アプリケーション仕様.md)

## どこから入るか

current `main` では internal user だけが、案件配下の `文書一覧` で `ファイルをアップロード` panel を使える。

- `文書一覧` の upload panel に drop すると、選択中フォルダ (`upload_source_path`) 直下の追加候補として扱う
- 左の TreeView のフォルダや文書行に直接 drop した場合も、同じ manual upload flow に入る
- upload 後は必ず `document_version_path(result.version, upload_review: "1")` へ遷移し、notice で `差異を確認してOK/NGを選択してください。` と案内される

この runbook が扱うのは、その遷移後に版詳細画面で行う review です。upload panel 自体の検索・TreeView・ZIP 出力とは役割を分けます。

## 候補の作られ方

### 既存文書の版更新候補になるとき

次の条件がそろうと、current code は既存 `Document` を使い、新しい draft `DocumentVersion` だけを追加する。

- 文書行へ drop した
- `target_document_id` が付いている
- drop したファイル名が、その文書の source file 名と同じ

この場合:

- 既存 `Document` は増えない
- `latest_version` は upload 直後には切り替わらない
- `OK` を押すまで「最新版候補を 1 つ増やしただけ」の状態で止まる

### 新規文書候補になるとき

次のどちらかでは、current code は新しい `Document` を作る。

- 案件直下やフォルダへ drop して、既存 source path に一致する文書がまだない
- 既存文書行へ drop したが、ファイル名がその文書の source file 名と違う

この場合:

- 新しい `Document` と draft `DocumentVersion` が 1 つずつ作られる
- 既存文書行へ drop してファイル名が違うときも、同じ source directory 直下の sibling 候補として扱う
- 新規候補の `latest_version` はまだ空で、`OK` を押すまで公開側の最新版にはならない

### Markdown とそれ以外の違い

- `.md` `.markdown` `.mdx` は manual upload 後に Docusaurus preview build が queue される
- PDF / Excel / Word など Markdown 以外は preview build を前提にせず、添付・元ファイル確認中心で読む

そのため Markdown 候補では、review 画面直後に `Docusaurusプレビュー生成中` が見えることがある。

## review 画面で最初に見る場所

upload 後の版詳細画面では、まず `アップロード候補の確認` card を見る。

- `OK：この内容を反映`: 候補版を最新版として反映する
- `NG：この候補を破棄`: 候補版を破棄して一覧へ戻る
- `文書一覧へ戻る`: 同じ source directory を見直したいときの戻り先

その上で、版詳細画面の通常要素を次の順で使う。

1. `プレビュー状態`
   - Markdown 候補で HTML がまだ生成中か、もう本文確認できるかを切り分ける
2. `比較対象` と `変更サマリ`
   - 既存文書の版更新候補なら、何と比べているか、差分の大きさがどれくらいかを先に把握する
3. `版差分ビュー`
   - `Markdown本文の行単位diff`、`HTML差分`、`表セル差分`、`左右確認` を必要な粒度だけ使う
4. `添付・元ファイル`
   - 新規文書候補や non-Markdown 候補では、ここで実ファイル名、分類、件数を優先して確認する

版詳細画面自体の読み方は [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md) を正本にし、この runbook は upload review の判断順だけを補う。

## `OK` を押すとどうなるか

`OK：この内容を反映` は `decision=approve` で review を確定する。

current behavior:

- draft manual upload 版が published になる
- 対象文書の `latest_version` がその版へ切り替わる
- redirect 先は対象文書の表示導線 (`project_document_path(..., version_id: uploaded_version.public_id)`) になる
- notice で `誤りがあればすぐ取り消せます。` と案内される

確認ポイント:

- 既存文書の版更新候補では、意図した文書の最新版だけが切り替わっているか
- 新規文書候補では、文書名・source path・添付が想定どおりに作られているか
- Markdown 候補では、preview build がまだなら本文ではなく差分や添付を先に見てよい

## `NG` を押すとどうなるか

`NG：この候補を破棄` は `decision=reject` で候補版を破棄する。

current behavior:

- 候補版は archived になる
- 既存文書の `latest_version` は切り替わらない
- redirect 先は `project_documents_path(project, q: version.source_directory)` で、同じ source directory を一覧で見直せる

向いている場面:

- drop 先やファイル名を間違えた
- 差分を見た結果、まだ最新版へ反映したくない
- sibling 新規文書として作られたが、意図は既存文書更新だった

## 反映後に取り消したいとき

manual upload 版を `OK` で反映したあと、その版が current `latest_version` なら、同じ版詳細画面の `アップロード後の確認` card から `このアップロードを取り消す` を使える。

current behavior:

- 最新 manual upload 版だけを rollback 対象にする
- previous version があれば、その版へ `latest_version` を戻す
- 取り消した manual upload 版は archived になる
- redirect 先は戻した先の版詳細画面

つまり、`OK` を押した直後に誤りへ気づいた場合でも、「最新版の manual upload を 1 つだけ戻す」導線は current code にある。

## 迷ったときの切り分け

- どのフォルダ直下へ drop した扱いかを見直したい: [文書一覧の検索・実用フィルタ・ZIP出力 runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
- 差分、HTML、添付、品質チェックのどこを読むか迷う: [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md)
- 既存文書更新か新規文書候補かを見分けたい: `Document` が増えているか、`latest_version` がまだ空か、source file 名が一致していたかを見る
- `OK` 済みだが誤りだった: 同じ版詳細の `アップロード後の確認` から rollback を使う
- drag & drop 自体が動かない: この runbook では直さない。既知の実装課題は issue `#470` を参照する

## current support の境界

- この runbook は current manual upload review flow だけを扱う
- drag & drop 実装の不具合修正、複数ファイル一括 upload UX、承認ポリシーの新設は含めない
- `OK` / `NG` / rollback の current runtime behavior を説明するが、新しい公開判断基準は定義しない
- 文書一覧 runbook や版詳細 runbook の内容を全面複製せず、upload review の入口だけを橋渡しする

## 関連文書

- [文書一覧の検索・実用フィルタ・ZIP出力 runbook](./文書一覧の検索・実用フィルタ・ZIP出力runbook.md)
- [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md)
- [アプリケーション仕様](./アプリケーション仕様.md)
- [README](../README.md)
- [docs/README](./README.md)