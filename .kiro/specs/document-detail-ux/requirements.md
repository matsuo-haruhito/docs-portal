# Requirements Document

## Introduction

文書詳細画面（`documents/show`）の UI/UX を「操作マニュアルを見なくても機能を把握できる」水準に引き上げる。共通 ViewComponent 基盤の整備、ナビゲーション構造の強化（パンくず + ページ内セクションナビ）、ステータスの「次のアクション」誘導を柱とし、ヒーロー領域・属性パネル・コメントワークスペースを改善する。

## Glossary

- **Document_Detail_Page**: 文書詳細画面（`documents/show`）。文書の本文プレビュー、属性情報、コメント、版一覧を表示する画面
- **ViewComponent**: Rails の ViewComponent gem によるサーバーサイド再利用可能 UI 部品
- **Section_Nav**: ページ内セクションナビゲーション。スティッキー表示されるタブ型アンカーリンク
- **Breadcrumb**: パンくずリスト。画面の階層位置を示すナビゲーション
- **Status_Badge**: 文書版のステータスを色とテキストで伝えるバッジ UI 部品
- **Info_Tooltip**: 項目名・見出し・ラベルの補足説明を表示するツールチップ
- **Help_Tooltip**: 操作ガイド用のツールチップ。ボタンやアクションの用途を説明する
- **Empty_State**: データが 0 件の場合に表示する案内 UI（説明 + 推奨アクション）
- **Page_Header**: 画面タイトル、サブタイトル、パンくず、アクションボタンを統一的に描画するコンポーネント
- **Hero_Area**: 文書詳細画面上部のタイトル・ステータス・操作ボタン領域
- **Attribute_Panel**: 文書の属性情報（カテゴリ、重要度、タグ、版一覧等）を表示するセクション群
- **Comment_Workspace**: 文書コメント（Q&A、確認事項）の投稿・閲覧領域
- **Internal_Admin**: 案件・文書・権限・公開状態を管理する社内管理者ロール
- **External_User**: 許可された文書を閲覧し、添付ファイルをダウンロードする社外ユーザーロール
- **FAB**: Floating Action Button。コメントワークスペースの開閉トリガー

## Requirements

### Requirement 1: ViewComponent 基盤セットアップ

**User Story:** As a 開発者, I want 共通 UI 部品を ViewComponent として整備したい, so that 複数画面で一貫した UI を提供し、重複実装を防げる。

#### Acceptance Criteria

1. THE ViewComponent SHALL provide an InfoTooltipComponent that accepts a `label` parameter (the term being explained) and a `description` parameter (the explanation text, maximum 200 characters), and renders a focusable icon adjacent to the label text with the description shown on hover and focus
2. THE ViewComponent SHALL provide a HelpTooltipComponent that accepts a `description` parameter (the guidance text, maximum 200 characters) and renders a focusable help icon (without a visible label) with the description shown on hover and focus
3. THE ViewComponent SHALL provide a PageHeaderComponent that accepts a `title` parameter, an optional `subtitle` parameter, a `breadcrumbs` slot accepting multiple breadcrumb items, and an `actions` slot accepting action links or buttons, and renders them in a consistent `header` element structure
4. THE ViewComponent SHALL provide a StatusBadgeComponent that accepts a `status` parameter (determining visual tone class), a `label` parameter (displayed text conveying the state alongside the color), and an optional `tooltip` parameter, and renders a badge where both color and text communicate the state
5. THE ViewComponent SHALL provide an EmptyStateComponent that accepts a `heading` parameter, a `description` parameter, and an `actions` slot for recommended next-step links or buttons, rendered as a centered guidance block
6. WHEN InfoTooltipComponent or HelpTooltipComponent is rendered, THE ViewComponent SHALL include `tabindex="0"` and an `aria-label` attribute whose value is the `description` parameter text, enabling keyboard-only users to access the tooltip content
7. WHEN a tooltip component element is focused or hovered, THE ViewComponent SHALL display the tooltip text using CSS `:hover` and `:focus` pseudo-class rules without requiring JavaScript
8. IF a required parameter (`label` for InfoTooltipComponent, `description` for tooltip components, `title` for PageHeaderComponent, `status` or `label` for StatusBadgeComponent, `heading` for EmptyStateComponent) is nil or blank, THEN THE ViewComponent SHALL raise an `ArgumentError` at render time indicating the missing parameter name

---

### Requirement 2: パンくずリスト強化

**User Story:** As a Internal_Admin, I want 文書詳細画面に「案件 → 文書一覧 → 文書名 → 版」の階層パンくずを表示したい, so that 現在位置を把握し、上位画面へ素早く戻れる。

#### Acceptance Criteria

1. THE BreadcrumbComponent SHALL render a `nav` element with `aria-label="パンくず"` containing an ordered list (`ol`) of hierarchical link items separated by a visual delimiter (CSS-generated or inline separator)
2. WHEN Document_Detail_Page is displayed, THE BreadcrumbComponent SHALL show the hierarchy as clickable links in this order: 案件名（リンク先: 案件の文書一覧画面） → 文書名（リンクなし、現在ページ）
3. WHEN Document_Detail_Page is displayed with a specific version selected (URL パラメータで版が指定されている), THE BreadcrumbComponent SHALL show: 案件名（リンク先: 案件の文書一覧画面） → 文書名（リンク先: 文書詳細画面） → 版ラベル（`version_label` の値、リンクなし、現在ページ）
4. THE BreadcrumbComponent SHALL mark the final item (current page) with `aria-current="page"` and render it as plain text without a link
5. WHEN a breadcrumb item label exceeds 200 characters, THE BreadcrumbComponent SHALL truncate the displayed text with `text-overflow: ellipsis` and set the full text as the element's `title` attribute

---

### Requirement 3: ページ内セクションナビゲーション

**User Story:** As a Internal_Admin, I want 「本文 / 属性 / コメント / 版一覧」のスティッキーなセクションナビを表示したい, so that 長いページでも目的のセクションへ即座にジャンプできる。

#### Acceptance Criteria

1. THE Section_Nav SHALL render a sticky navigation bar immediately below the Hero_Area containing tab-style anchor links for each visible section, with a maximum of 10 tabs displayed simultaneously
2. WHILE the user scrolls past the Hero_Area, THE Section_Nav SHALL remain fixed at the top of the viewport using `position: sticky` with a `z-index` sufficient to overlay page content, and SHALL maintain a height no greater than 48px to minimize content occlusion
3. WHEN a section's top edge enters the top 30% of the viewport, THE Section_Nav SHALL highlight the corresponding tab by applying an `is-active` class, detected via IntersectionObserver with a `rootMargin` of "-0% 0% -70% 0%", and SHALL remove `is-active` from all other tabs
4. WHEN a Section_Nav tab is clicked, THE Document_Detail_Page SHALL smooth-scroll to the corresponding section anchor, offsetting the scroll position by the height of the sticky Section_Nav so that the section heading is not obscured
5. THE Section_Nav SHALL use `role="tablist"` on the container, `role="tab"` on each link, and `aria-controls` attributes linking each tab to its corresponding section's `id`, and SHALL set `aria-selected="true"` on the active tab
6. WHEN the document has no embedded HTML view (i.e., no renderable Docusaurus HTML content exists for the document), THE Section_Nav SHALL omit the "本文" tab entirely from the DOM rather than rendering it in a hidden state
7. WHEN the viewport width is less than 768px, THE Section_Nav SHALL allow horizontal scrolling of tabs via `overflow-x: auto` without line-wrapping, and SHALL display a visual scroll affordance (fade or shadow) on the trailing edge when tabs overflow the container width

---

### Requirement 4: ヒーロー領域のリファクタリング

**User Story:** As a External_User, I want 文書詳細画面のヒーロー領域で「今何が見られて、次に何ができるか」を一目で把握したい, so that 迷わず目的の操作に進める。

#### Acceptance Criteria

1. THE Hero_Area SHALL render as a single shared partial/component used in both the embedded-view-available path and the no-embedded-view path, containing title, source path breadcrumb, version Status_Badge, and action buttons in that order
2. WHEN Document_Detail_Page is loaded, THE Hero_Area SHALL display the viewed version's status (draft, published, or archived) as a Status_Badge with both color and text label
3. WHEN a user hovers or focuses on the Status_Badge, THE Status_Badge SHALL display a tooltip explaining the status meaning and suggesting the next available action
4. WHEN a user hovers or focuses on an action button, THE Hero_Area SHALL display a Help_Tooltip explaining the button's purpose
5. WHEN the document has an embedded HTML view available, THE Hero_Area SHALL display a distinguishable visual indicator (icon or badge) adjacent to the title that communicates preview availability without requiring user interaction
6. WHEN the document has no embedded HTML view, THE Hero_Area SHALL display a visual indicator adjacent to the title that communicates no preview is available, distinct from the preview-available indicator
7. IF the current user is an external user, THEN THE Hero_Area SHALL display only navigation buttons (案件トップ, 文書一覧, 版詳細) and the download button when a downloadable file exists, and SHALL NOT display internal-only actions such as upload or popout

---

### Requirement 5: 属性パネルの構造改善

**User Story:** As a Internal_Admin, I want 属性パネルを折りたたみ一括ではなくセクション別カードで表示したい, so that 必要な情報を見つけやすくなる。

#### Acceptance Criteria

1. THE Attribute_Panel SHALL replace the single `details.document-context-drawer` element with individual section cards rendered in this order: 属性、版一覧、関連文書、確認依頼
2. WHEN Attribute_Panel sections are rendered, THE Document_Detail_Page SHALL assign each section a unique `id` attribute (e.g. `id="attributes"`, `id="versions"`, `id="related-documents"`, `id="approval-requests"`) that corresponds to Section_Nav anchors
3. THE Attribute_Panel SHALL display document attributes using `dl` (definition list) elements containing at minimum: 案件、カテゴリ、ファイル種、重要度、公開範囲、タグ
4. WHEN a version is listed in the 版一覧 section, THE Attribute_Panel SHALL display the version status using Status_Badge with a tooltip that explains the status meaning (e.g. 「公開中」「下書き」「アーカイブ済み」)
5. WHEN the 関連文書 section has zero items, THE Attribute_Panel SHALL render Empty_State with a heading indicating no related documents exist, a description explaining what related documents are, and a link to the document list as the recommended action
6. WHEN the 確認依頼 section has zero items, THE Attribute_Panel SHALL render Empty_State with a heading indicating no approval requests exist, a description explaining the purpose of approval requests, and a link to create a new approval request as the recommended action
7. THE Attribute_Panel SHALL display Info_Tooltip on the following attributes in the 属性 `dl` section: カテゴリ（文書の分類を示す）, 重要度（閲覧優先度や通知に影響する）, 公開範囲（external user の閲覧可否を制御する）
8. IF the 出力時の扱い section contains export-related notes (透かし、ZIP出力形式), THEN THE Attribute_Panel SHALL render them in a dedicated card with an Info_Tooltip on the section heading explaining that these settings affect download and external delivery output

---

### Requirement 6: コメントワークスペースの直感性改善

**User Story:** As a Internal_Admin, I want コメントワークスペースの FAB に未解決件数バッジを表示し、タブの用途をツールチップで説明したい, so that 未対応のコメントを見逃さず、各タブの違いを理解できる。

#### Acceptance Criteria

1. WHEN the Comment_Workspace is in floating mode and unresolved comment count is 1 or more, THE FAB SHALL display a count badge overlaid on the button showing the total number of unresolved comments (open Q&A threads plus unresolved 確認事項 for Internal_Admin, open Q&A threads only for External_User), capped at "99+" when the count exceeds 99
2. WHEN unresolved comment count is zero, THE FAB SHALL hide the count badge entirely (no "0" badge rendered)
3. WHEN a user hovers or focuses on a Comment_Workspace tab label, THE Comment_Workspace SHALL display an Info_Tooltip explaining what comments are shown in that tab (e.g., "すべて" tab: 全種別のコメントを表示, "Q&A" tab: 外部/利用者にも見える質問スレッドを表示, "確認事項" tab: 内部限定の確認・指摘を表示, "未解決" tab: 回答やクローズ・解決がされていないコメントを表示)
4. WHEN a user hovers or focuses on the comment mode switch (質問/確認事項), THE Comment_Workspace SHALL display a Help_Tooltip explaining that 質問 creates Q&A visible to external users while 確認事項 creates an internal-only review item
5. WHEN the Comment_Workspace has zero comments in the active tab (after applying any active search/author filter), THE Comment_Workspace SHALL render Empty_State with a heading indicating no comments exist, a description suggesting the user add a comment via the input form above, and a recommended action link scrolling to the input form
6. THE Comment_Workspace section SHALL have `id="comments"` to enable Section_Nav linkage

---

### Requirement 7: 日本語完結とアクセシビリティ

**User Story:** As a External_User, I want 画面上のすべての UI テキストが日本語で表示され、キーボードのみで操作できるようにしたい, so that 英語ラベルに戸惑わず、スクリーンリーダーでも利用できる。

#### Acceptance Criteria

1. THE Document_Detail_Page SHALL display all UI labels, button text, tooltip text, Empty_State messages, status badge text, and navigation link text in Japanese, with no English-only string visible to the user
2. THE Document_Detail_Page SHALL ensure all interactive elements (links, buttons, tabs, tooltip triggers, form controls) are reachable and operable via keyboard Tab navigation in a logical reading order (top-to-bottom, left-to-right within each section)
3. WHEN Section_Nav, Breadcrumb, or Comment_Workspace navigation elements are rendered, THE Document_Detail_Page SHALL include `aria-label` attributes in Japanese that describe the navigation purpose (e.g., "文書詳細ナビゲーション", "パンくずリスト")
4. WHEN tooltips are rendered, THE Document_Detail_Page SHALL ensure tooltip content is accessible to screen readers via `aria-describedby` linking the trigger element to the tooltip content, and the tooltip SHALL be displayed on both hover and focus of the trigger element
5. WHEN a user presses the Escape key while a tooltip is visible, THE Document_Detail_Page SHALL close the tooltip and return focus to the trigger element
6. IF an enum value, validation error message, or flash message is displayed, THEN THE Document_Detail_Page SHALL render the corresponding Japanese translation from the locale file, never the raw enum key or English fallback

---

### Requirement 8: 画面状態パターンに応じた表示制御

**User Story:** As a Internal_Admin, I want 文書の状態（本文あり/なし × 版あり/なし × ロール）に応じて適切な UI が表示されるようにしたい, so that どの状態でも画面が破綻せず、適切な案内が出る。

#### Acceptance Criteria

1. WHEN the document version has a rendered Docusaurus site available (`rendered_site_available?`) or an embeddable viewer file (`embedded_view_file`), THE Document_Detail_Page SHALL display the iframe viewer with auto-height sizing (minimum height 480px), Section_Nav as a collapsible `details` drawer labeled "文書情報・操作・版一覧を開く", and Comment_Workspace in floating mode (collapsed by default, opened via FAB button)
2. WHEN the document version has neither a rendered Docusaurus site nor an embeddable viewer file (i.e. `@viewer_iframe_src` is nil), THE Document_Detail_Page SHALL display Attribute_Panel and detail sections inline (not inside a drawer), hide the iframe viewer area entirely, and render Comment_Workspace in inline mode (expanded by default, rendered before detail sections)
3. WHEN the document has no viewable versions for the current user (`@versions` is empty), THE Document_Detail_Page SHALL render the 版一覧 section as an empty list without guidance text, and SHALL omit the "本文で開く" link and version-related actions from the 主要操作 group
4. WHILE the user is External_User, THE Document_Detail_Page SHALL hide the following internal-only sections: 確認事項タブ in Comment_Workspace, 確認事項投稿フォーム (comment_type: request_change), 確認依頼作成フォーム and confirmation request table, 手動アップロード用ドラッグ＆ドロップ案内, and the handoff summary in Comment_Workspace header
5. WHILE the user is Internal_Admin, THE Document_Detail_Page SHALL display all management sections including: 確認事項タブ and its投稿フォーム in Comment_Workspace, 確認依頼作成フォーム with approver selection, recent confirmation requests table (up to 5 件), 手動アップロード用ドラッグ＆ドロップ overlay on the iframe area (with upload URL pointing to `project_document_uploads_path`), and the handoff summary showing unresolved counts
6. IF the user is Internal_Admin AND the embedded view is available, THEN THE Document_Detail_Page SHALL wrap the iframe in a manual-document-upload controller that accepts single-file drag-and-drop, showing a drop overlay with the message "ここに1ファイルをドロップ" during drag-over state
