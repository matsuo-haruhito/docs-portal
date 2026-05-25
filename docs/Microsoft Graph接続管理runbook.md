# Microsoft Graph接続管理runbook

この runbook は、管理画面 `admin/microsoft_graph_connections` で案件ごとの Office preview 接続を日常運用で見直すときの読み順をまとめたものです。接続前提や fallback の仕様そのものは [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を正本とし、この文書では current UI 上で何を確認するかに絞ります。

## まず見る画面

- 管理画面のメニューから `Microsoft Graph接続` を開きます。
- 一覧では `案件 / 接続名 / Tenant / Client / Drive / プレビュー用フォルダ / 状態` をまとめて見返せます。
- 同じ画面の下側で新規登録、各行の `編集` から既存設定の更新、`削除` から不要設定の除去を行います。

## 日常確認の順番

1. 対象案件に対して、今使う接続がどの行かを `案件` と `接続名` で確認する
2. `状態` が `有効` になっているかを見る
3. `Drive` 列の `drive_id` と、`プレビュー用フォルダ` 列の `preview_folder_path` が想定どおりか確認する
4. 必要に応じて `Tenant / Client` を見て、別テナントや別アプリの値が混ざっていないか確認する
5. Office preview が開かないときは、この文書の `preview 不達時の戻り先` へ進む

## 複数行が並んでいるときの見方

- 一覧は `name`, `id` 順で並びます。
- current code では、同一案件に `有効` な接続が複数あっても、preview に使うのは 1 件だけです。
- 既存 docs どおり、運用上は `1案件1有効接続` を基本にしてください。
- 同一案件に有効行が複数ある場合は、不要な行を `無効` に寄せるか削除し、どれを使うかが一覧だけで分かる状態へ戻します。
- この選択ルール自体を改善したい場合は、open issue [#529](https://github.com/matsuo-haruhito/docs-portal/issues/529) を参照してください。

## `Drive ID` の見直しポイント

- `Drive` 列には preview 用一時アップロード先の `drive_id` が出ます。
- 案件をまたいで同じ値を使うこと自体は current code 上で禁止されていませんが、運用上はどの案件の preview 用保存先かを追えるようにしておく方が安全です。
- `site_id` は一覧には出ないため、必要なら `編集` 画面で補助メモとして確認します。
- preview 先を切り替えた直後は、古い `drive_id` のまま残っていないかを最初に確認します。

## `プレビュー用フォルダ` の見直しポイント

- `preview_folder_path` は一覧の `プレビュー用フォルダ` 列で確認できます。
- current validation では、空欄、`/` 始まり、`..` を含む相対パスは保存できません。
- 初期値は `docs-portal-previews` です。案件ごとに preview 用フォルダを分けている場合は、名前だけでどの用途か分かる状態を保ちます。
- Office preview が失敗したときは、`drive_id` だけでなく `preview_folder_path` の typo や、意図しないフォルダ名変更も確認します。

## 編集時に見る項目

- `案件`: どの案件の Office preview に使う接続か
- `接続名`: 一覧で識別しやすい表示名か
- `認証方式`: current code では `client_credentials` のみ
- `Tenant ID` / `Client ID`: 想定するテナントとアプリか
- `Client secret`: 変更時のみ再入力が必要か
- `Site ID`: 必須ではないが、Drive ID の取得元を追跡したいときの補助メモ
- `Drive ID`: preview 用一時アップロード先の識別子
- `プレビュー用フォルダ`: 相対パスで安全に保存できる値か
- `状態`: `有効` / `無効` の切り替えが案件運用と一致しているか

## preview 不達時の戻り先

1. まずこの一覧で、対象案件に `有効` な接続があるか確認する
2. `Drive ID` と `プレビュー用フォルダ` が、切り替え前の値や typo のある値に戻っていないか確認する
3. 入力値自体が妥当か、`編集` 画面で `Tenant ID` / `Client ID` / `Site ID` も含めて見直す
4. 接続前提や fallback 条件を確認したい場合は [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) へ戻る
5. 外部フォルダ同期や `.env` 側の責務分担を確認したい場合は [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md) へ戻る

## この runbook で扱わないこと

- Azure / Microsoft Graph 側の権限設計そのもの
- preview URL の選択ロジック変更
- 同一案件の有効接続を 1 件に制約する runtime 実装
- SharePoint / OneDrive 同期機能の後続仕様

## 関連ドキュメント

- [README](../README.md)
- [docs/README](./README.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [preview接続と外部フォルダ同期の設定責務](./preview%E6%8E%A5%E7%B6%9A%E3%81%A8%E5%A4%96%E9%83%A8%E3%83%95%E3%82%A9%E3%83%AB%E3%83%80%E5%90%8C%E6%9C%9F%E3%81%AE%E8%A8%AD%E5%AE%9A%E8%B2%AC%E5%8B%99.md)
- [Issue #529](https://github.com/matsuo-haruhito/docs-portal/issues/529)