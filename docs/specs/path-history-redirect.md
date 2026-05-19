# Path history / redirect

Path history / redirect は、文書の slug、Docusaurus site path、Markdown entry path が変わった場合でも、旧 URL から現在の閲覧 URL へ誘導するための仕様です。

## 目的

- Markdown entry path 変更後も、旧 `site_path` の URL を可能な範囲で維持する
- Docusaurus preview の入口が変わっても、利用者を現在の canonical path へ誘導する
- いきなり永続 model を増やさず、まず既存の文書版履歴から安全に resolver する
- 将来の slug history / archived / deleted handling に拡張しやすい形にする

## 現在の resolver

`DocumentPathHistoryResolver` は、同一 document 内の過去 version の `html_view_site_path` と明示 metadata の `site_paths` を履歴として扱います。

入力:

- `document`
- `requested_site_path`
- `canonical_version`
- `candidate_versions`

出力:

- `status`
  - `canonical`
  - `moved`
  - `missing`
- `requested_path`
- `canonical_path`
- `canonical_version`
- `matched_version`

`DocumentSlugHistoryResolver` は、同一 project 内の document versions から、明示 metadata の `slugs` と旧 slug とみなせる source/path 由来の候補を現在の document slug へ解決します。

入力:

- `project`
- `requested_slug`
- `candidate_documents`

出力:

- `status`
  - `moved`
  - `missing`
- `requested_slug`
- `canonical_document`
- `matched_version`
- `matched_source`

`DocumentPathHistoryMetadata` は、明示 metadata file から slug / site path 履歴を読み取る reader です。metadata は resolver でも使い、quality check では source / warning を表示します。

## user-facing status

`DocumentHistoryStatusPresenter` は、resolver や将来の DB table 由来の履歴状態を利用者向け文言に変換します。

| status | label | message |
| --- | --- | --- |
| `canonical` | 現在の場所 | このURLは現在の文書位置です。 |
| `moved` | 移動済み | 旧URLから現在の文書位置へ移動しました。 |
| `missing` | 未解決 | このURLに対応する現在の文書位置は見つかりませんでした。 |
| `archived` | アーカイブ済み | このURLに対応する文書はアーカイブ済みです。 |
| `deleted` | 削除済み | このURLに対応する文書は削除済みです。 |

現時点の resolver は主に `canonical` / `moved` / `missing` を返します。`archived` / `deleted` は DB table 化や明示 metadata 拡張後に使う予定の user-facing 状態です。

## explicit metadata

文書版の添付・元ファイルに、次のいずれかの YAML file を置くことで明示的な path history metadata として認識します。

- `.docs-portal-history.yml`
- `.docs-portal-history.yaml`
- `.path-history.yml`
- `.path-history.yaml`
- `path-history.yml`
- `path-history.yaml`

YAML 形式:

```yaml
path_history:
  slugs:
    - previous-guide
  site_paths:
    - docs/previous-guide
```

対応 key は `slugs` と `site_paths` のみです。未対応 key は `path_history_metadata` warning として表示します。

## canonical 判定

要求された path を `DocumentVersion.normalize_site_page_path` で正規化し、現在の canonical version の `normalized_html_view_site_path` 配下であれば `canonical` とします。

例:

```text
canonical version html_view_site_path: docs/current-guide
requested site_path: docs/current-guide/appendix
status: canonical
```

## moved 判定

要求された path が現在の canonical path ではなく、明示 metadata の `site_paths` に一致する場合は `moved` とします。metadata に一致した場合は suffix 推定をせず、現在 version の canonical path へ誘導します。

明示 metadata に一致しない場合は、同一 document の過去 version の `normalized_html_view_site_path` 配下にあるかを見ます。この場合、旧 path の suffix は現在 path に引き継ぎます。

```text
old version html_view_site_path: docs/previous-guide
current version html_view_site_path: docs/current-guide
requested site_path: docs/previous-guide/appendix/page
canonical_path: docs/current-guide/appendix/page
status: moved
```

slug については、要求された slug が現在の document slug と一致せず、同一 project 内の document version に次のような一致候補がある場合に `moved` とします。

- 明示 metadata の `path_history.slugs`
- `source_file_name` の拡張子を除いた名前
- `source_relative_path` の末尾ファイル名から拡張子を除いた名前
- `source_directory` の末尾 segment
- `html_view_site_path` の末尾 segment
- `site_build_path` の末尾 segment

slug 候補は NFKC 正規化・小文字化・記号整理をして比較します。明示 metadata の slug 候補を source/path 由来の推定候補より優先します。

## missing 判定

現在 version にも過去 version にも一致しない場合は `missing` とします。

現時点では `missing` の場合に専用 404 や archived 表示へ分岐せず、既存の viewer 処理に委ねます。これは挙動変更の範囲を小さくするためです。

## document reader integration

`DocumentsController#show` では、reader 用の `site_path` に対して resolver を呼びます。

- slug が現在 document に一致する場合は通常表示
- slug が存在せず `DocumentSlugHistoryResolver` が `moved` を返した場合は現在 document slug へ `301 Moved Permanently`
- `site_path` が `moved` の場合は `301 Moved Permanently` で現在の `site_path` に redirect
- `canonical` の場合はそのまま viewer を表示
- `missing` の場合は従来どおり viewer 処理を継続

slug redirect 先には `previous_slug` を含めます。redirect 後の reader では、`previous_slug` がある場合に `DocumentHistoryStatusPresenter` の `moved` 表示を使い、旧 URL 識別子と現在 slug を `old -> current` 形式で示します。

site path redirect 先には現在の `version_id`、canonical `site_path`、元の `previous_site_path` を含めます。redirect 後の reader では、`previous_site_path` がある場合に `DocumentHistoryStatusPresenter` の `moved` 表示を使い、旧 path と現在 path を `old -> current` 形式で示します。

## project site integration

`ProjectSitesController#show` でも、HTML 直アクセス用の `site_path` に対して同じ resolver を呼びます。

- asset path、つまり `assets/...` は cacheable asset として従来どおり扱い、path history redirect の対象外にする
- `moved` の場合は `301 Moved Permanently` で現在の project site `site_path` に redirect
- redirect 先は query string の `site_path=...` ではなく、`/projects/:project_code/site/:site_path` の canonical path 形式にする
- `previous_site_path` を redirect 先にも残す
- `embedded=1` が付いている場合は redirect 先にも `embedded=1` を残す
- `canonical` / `missing` の場合は従来どおり renderer で処理する

project site route が HTML ページを reader に誘導する場合も、`previous_site_path` を reader redirect に引き継ぎます。これにより、project site 直アクセスから始まった旧 path 移動でも、最終的な reader 画面で同じ移動 notice を表示できます。

これにより、reader 経由の URL と Docusaurus HTML 直アクセス URL のどちらでも、旧 entry path から現在の canonical path へ誘導できます。

## quality check

`DocumentVersionQualityChecker` は、同一 document の過去 version に現在とは異なる HTML entry path がある場合、`path_history` warning を表示します。

warning detail は次の形です。

```text
old/path, another/old/path -> current/path
```

この warning はエラーではありません。旧 URL から現在 URL へ redirect できる履歴があることを、公開前確認やレビューで見落とさないための通知です。

`DocumentPathHistoryMetadata` が source file を検出した場合は `path_history_metadata` info を表示します。未対応 key や YAML parse error は `path_history_metadata` warning として表示します。

## current limitations

- slug history は metadata と source/path 由来の推定で扱うが、明示 DB table はまだ持たない
- site path history は metadata と過去 version の path で扱うが、明示 DB table はまだ持たない
- `archived` / `deleted` は user-facing status として定義済みだが resolver からはまだ返さない
- 別 document への移動はまだ扱わない
- asset path は redirect しない

## next steps

- path history を DB table で明示管理する
- metadata と DB table の優先順位を整理する
- `archived` / `deleted` を resolver と DB table に接続する
