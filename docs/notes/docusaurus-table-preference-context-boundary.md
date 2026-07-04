# Docusaurus table preference context boundary

このメモは、Markdown / Docusaurus table を `rails_table_preferences` へ full 接続する前に、current `DocusaurusSiteRenderer` が付与している table metadata と preference context key の読み方を固定するための first slice です。

## Current support

`DocusaurusSiteRenderer` は generated HTML の real `<table>` を rewrite し、通常表示と `embedded=1` 表示の両方で同じ metadata contract を付与します。

- wrapper: `div.portal-doc-table-preference-wrapper`
- table: `table.portal-doc-preference-table`
- document version: `data-docs-portal-document-version`
- normalized site path: `data-docs-portal-site-path`
- per-page table index: `data-docs-portal-table-index`
- stable table key: `data-rails-table-preferences-table-key`

Stable table key は `DocumentVersion.public_id`、normalized site path、per-page table index から作ります。site path は Base64 URL-safe 文字列にして、path separator が key に直接入らないようにします。

## Embedded / standalone parity

通常表示は portal navigation と version switcher を追加します。`embedded=1` は Docusaurus chrome と portal chrome を外し、親ページ側の iframe height sync に任せます。

ただし table preference context は表示 chrome ではなく、document version、normalized site path、table index に紐づくため、通常表示と embedded 表示で同じ key を使います。これにより、後続 slice が browser evidence や UI を追加するときに、同じ文書版・同じ site page・同じ table を同一 context として読めます。

## Metadata candidates and gaps

Preference context に使える current metadata:

- `DocumentVersion.public_id`: 文書版単位の安定した識別子
- normalized site path: Docusaurus generated page の viewer-side path
- table index: 同一 page 内の複数 table を分ける番号
- stable table key: 上記を結合した current key

不足または後続判断に残すもの:

- table caption / heading 由来の semantic key
- Markdown source position 由来の stable key
- column identity / column visibility metadata
- preset UI / saved column schema
- upstream `rails_table_preferences` API 変更

## Boundary

この first slice は context key と renderer rewrite 境界の読み返しだけを扱います。Markdown table の column visibility、preset UI、full `rails-table-preferences` controller 接続、preference schema 変更、Docusaurus renderer 全体の再設計、pinned ref bump は #475 側に残します。
