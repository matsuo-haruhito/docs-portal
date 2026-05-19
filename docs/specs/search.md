# 検索責務

この文書は、docs-portal における検索機能の責務分担を整理する。

Docusaurus viewer、Rails portal、添付・元ファイル viewer、将来の検索 index が混ざると、検索対象・権限・表示導線が曖昧になりやすい。そのため、検索は用途ごとに明確に分ける。

## 基本方針

- 検索は、権限判定より前に文書名・本文・添付名・移動先などを漏らしてはならない
- Rails 側の検索は、常に current user が閲覧可能な Project / Document / DocumentVersion / DocumentFile だけを対象にする
- Docusaurus iframe 内の検索は、現在表示している same-origin HTML に閉じた文書内検索として扱う
- iframe 内検索と portal 横断検索は、UI上も責務も分ける
- 検索結果から viewer shell に戻る場合は、Rails route を通して権限判定を再実行する
- 検索 index を作る場合は、company / project / publication scope ごとに分離し、権限外文書が混ざらないようにする

## 検索の種類

| 種類 | 対象 | 主な利用場所 | 権限の考え方 |
| --- | --- | --- | --- |
| 文書内検索 | 現在表示中の HTML本文 | Docusaurus viewer iframe | その文書を表示できていることが前提 |
| 表内検索 | 現在表示中の Markdown table | table toolbar | その文書を表示できていることが前提 |
| codeblock 検索 | 現在表示中の code block | codeblock toolbar / 将来拡張 | その文書を表示できていることが前提 |
| 添付一覧検索 | 版に紐づく DocumentFile | 版詳細 / 添付一覧 | fileごとの閲覧権限を適用 |
| 案件内検索 | Project内の文書・版・添付 | Project詳細 / dashboard | Projectと各文書の閲覧権限を適用 |
| 会社内検索 | company scope の文書 | dashboard / global search | companyとroleに応じて制御 |
| 管理検索 | 管理対象の会社・案件・文書 | admin画面 | admin / company_master_admin の管理権限を適用 |
| 公開検索 | 外部公開対象 | 将来の standalone public build | public scope のみ index 化 |

## Docusaurus iframe 内検索

- Docusaurus iframe 内検索は、現在開いている HTML本文だけを対象にする
- same-origin iframe の場合のみ、Rails側の viewer拡張として検索UIを注入できる
- cross-origin になった場合は、検索UI注入に失敗しても viewer 表示自体を壊してはならない
- 検索対象は本文領域を優先し、navbar、footer、sidebar、toc などの viewer chrome は対象から外す
- 検索結果は iframe 内でハイライトし、必要なら該当位置へスクロールする
- iframe 内検索結果は portal 横断検索 index へ送信しない

## 表内検索

- 表内検索は、Markdown table viewer UX の一部として扱う
- 現在表示中の表だけを対象にする
- 一致セルをハイライトし、一致しない行を折りたためる
- 表内検索語は保存せず、ページを閉じると消える一時状態として扱う
- 表内検索は Markdown 原文や生成済みHTMLを変更しない

## Codeblock 検索 / anchor

- codeblock は、将来的に code block id、言語、行番号を検索・レビューコメント・検証結果の anchor として使えるようにする
- codeblock 内検索は、現在表示中の code block またはページ内の code block に限定する
- secret / token / password / authorization header などを含む可能性がある code block は、外部検索 index や外部送信の対象にしない
- codeblock action の validation / dry-run 結果は、検索 index ではなく一時的な viewer state として扱う

## Rails portal 横断検索

- Rails portal の検索は、Project / Document / DocumentVersion / DocumentFile / DocumentCatalog / DocumentSet を横断できる
- 検索結果は必ず権限判定後のものだけを返す
- 検索結果には、文書タイトル、版、抜粋、ファイル名、更新日時、project、status を表示できる
- 検索結果から本文へ遷移する場合は、viewer shell route を使う
- 検索結果から添付へ遷移する場合は、DocumentFile viewer registry を通す
- 旧 path に一致した場合は、Path history / redirect の解決を通して canonical target を表示する
- 検索結果に旧 path が含まれる場合は、必要に応じて「移動済み」や「現在の場所」を表示する

## Project 内検索

Project 内の文書一覧検索は、まず ActiveRecord scope 上で絞り込み、current user が閲覧可能な文書だけを一覧に残す。

現在の軽量検索対象は次の通り。

| match label | 主な対象 |
| --- | --- |
| `タイトル` | `documents.title` |
| `slug` | `documents.slug` |
| `タグ` | `document_tags.name`, `document_tags.normalized_name` |
| `バージョン` | `document_versions.version_label` |
| `source path` | `source_relative_path`, `source_directory`, `source_file_name` |
| `更新サマリ` | `document_versions.changelog_summary` |
| `本文` | `document_versions.search_body_text` |
| `添付ファイル名` | `document_files.file_name` |
| `添付tree path` | `document_files.storage_key` と表示用 `DocumentFile#tree_path` |
| `添付テキスト` | `document_files.search_text` |
| `キーワード` | `document_keywords.keyword`, `document_keywords.normalized_keyword` |

`DocumentFile#tree_path` は実体カラムではなく推定値を含むため、SQL 絞り込みでは `storage_key` を path 由来の検索対象として使い、結果表示の match label 判定では `tree_path` も見る。

## 添付・元ファイル検索

- 添付・元ファイル検索は、DocumentFile viewer registry と連携する
- 検索対象は file name、tree path、content type、metadata、必要に応じて抽出済み本文とする
- 大容量ファイルや binary file は、抽出済み metadata を中心に検索する
- Office / PDF / image の本文抽出は後続実装とし、まずは file name / path / metadata を対象にする
- download 権限がない利用者には、download only 結果ではなく権限申請導線を表示する

## 検索 index

- 検索 index を導入する場合、権限境界ごとに index を分ける
- 最低限、public / company / project / admin の scope を分ける
- index document には、Document public_id、DocumentVersion public_id、Project code、canonical path、source commit、build profile、updated_at を含める
- index には secret らしき code block や debug / hidden file の内容を入れない
- preview target metadata の hidden / debug は、既定では検索対象外とする
- admin 用検索では hidden / debug を検索できる場合があるが、UI上で通常検索と明確に分ける
- index 更新は DocumentVersion 作成、Docusaurus build 完了、metadata 更新、path history 更新に合わせて enqueue する
- stale index を検出した場合、検索結果に鮮度警告を表示できるようにする

## Docusaurus build profile との関係

- `portal_embedded` build では、Rails側の権限付き検索を主とし、iframe 内検索は現在文書内に限定する
- `standalone_public` build では、Docusaurus側の search plugin を有効化できる
- `admin_api_spec` build では、API仕様ページ内検索と codeblock action を重視する
- `preview_check` build では、broken link、metadata path、旧 path 参照を検証対象にする
- `diff_metadata` build では、見出し、table、codeblock、内部 link の index を生成し、差分・検索・anchorに使えるようにする

## UI方針

- viewer shell の検索UIは「この文書内を検索」と明示する
- portal global search は「閲覧可能な文書を検索」と明示する
- Project内検索は project context を表示し、全社検索と区別する
- 検索結果には、なぜ表示されているかを推測できる context を表示する
  - タイトル一致
  - 本文一致
  - 添付名一致
  - path一致
  - 旧path一致
- 権限がないため表示できない結果の件数は表示しない
- 0件の場合は、検索語の変更、project範囲の変更、権限申請導線を提示する

## 監査・ログ

- portal 横断検索は、必要に応じて検索語、検索scope、結果件数、実行ユーザーを access log または audit log に記録できる
- secret を含む可能性のある検索語は、ログ保存時に mask できるようにする
- iframe 内検索や表内検索の検索語は、既定ではサーバーへ送信せずログにも残さない
- admin検索は監査ログ対象にできるようにする

## 実装優先順位

1. 既存 viewer shell に文書内検索の仕様を合わせる
2. Project / dashboard の権限付き検索を整理する
3. DocumentFile file name / tree path 検索を追加する
4. Path history と canonical target を検索結果に反映する
5. build profile / diff metadata 由来の index を検索に使う
6. standalone public build の検索を分離する
