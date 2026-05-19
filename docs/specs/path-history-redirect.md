# Path history / redirect

Path history / redirect は、文書の slug、Docusaurus site path、Markdown entry path が変わった場合でも、旧 URL から現在の閲覧 URL へ誘導するための仕様です。

## 目的

- Markdown entry path 変更後も、旧 `site_path` の URL を可能な範囲で維持する
- Docusaurus preview の入口が変わっても、利用者を現在の canonical path へ誘導する
- いきなり永続 model を増やさず、まず既存の文書版履歴から安全に resolver する
- 将来の slug history / archived / deleted handling に拡張しやすい形にする

## 現在の resolver

`DocumentPathHistoryResolver` は、同一 document 内の過去 version の `html_view_site_path` を履歴として扱います。

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

## canonical 判定

要求された path を `DocumentVersion.normalize_site_page_path` で正規化し、現在の canonical version の `normalized_html_view_site_path` 配下であれば `canonical` とします。

例:

```text
canonical version html_view_site_path: docs/current-guide
requested site_path: docs/current-guide/appendix
status: canonical
```

## moved 判定

要求された path が現在の canonical path ではなく、同一 document の過去 version の `normalized_html_view_site_path` 配下にある場合は `moved` とします。

旧 path の suffix は現在 path に引き継ぎます。

```text
old version html_view_site_path: docs/previous-guide
current version html_view_site_path: docs/current-guide
requested site_path: docs/previous-guide/appendix/page
canonical_path: docs/current-guide/appendix/page
status: moved
```

## missing 判定

現在 version にも過去 version にも一致しない場合は `missing` とします。

現時点では `missing` の場合に専用 404 や archived 表示へ分岐せず、既存の viewer 処理に委ねます。これは挙動変更の範囲を小さくするためです。

## document reader integration

`DocumentsController#show` では、reader 用の `site_path` に対して resolver を呼びます。

- `moved` の場合は `301 Moved Permanently` で現在の `site_path` に redirect
- `canonical` の場合はそのまま viewer を表示
- `missing` の場合は従来どおり viewer 処理を継続

redirect 先には現在の `version_id` と canonical `site_path` を含めます。

## project site integration

`ProjectSitesController#show` でも、HTML 直アクセス用の `site_path` に対して同じ resolver を呼びます。

- asset path、つまり `assets/...` は cacheable asset として従来どおり扱い、path history redirect の対象外にする
- `moved` の場合は `301 Moved Permanently` で現在の project site `site_path` に redirect
- `embedded=1` が付いている場合は redirect 先にも `embedded=1` を残す
- `canonical` / `missing` の場合は従来どおり renderer で処理する

これにより、reader 経由の URL と Docusaurus HTML 直アクセス URL のどちらでも、旧 entry path から現在の canonical path へ誘導できます。

## current limitations

- slug 自体の履歴はまだ扱わない
- DB table として path history はまだ持たない
- archived / deleted / explicitly moved の状態管理はまだ持たない
- 別 document への移動はまだ扱わない
- asset path は redirect しない

## next steps

- slug history の resolver を追加する
- path history を metadata または DB table で明示管理する
- `canonical`, `moved`, `archived`, `deleted` を user-facing な状態として整理する
- quality check で古い path / canonical path の不整合を warning する
- redirect 先で古い path から移動したことを user-facing に軽く表示する
