# Implementation Plan: document-detail-ux

## Overview

文書詳細画面の UX 改善を、ViewComponent 基盤の整備 → 個別コンポーネント実装 → ビュー統合 → テストの順で段階的に実装する。依存関係の少ないベースコンポーネントから着手し、最終的に show.html.slim のリファクタリングで全体を統合する。

## Tasks

- [x] 1. ViewComponent 基盤セットアップとベースコンポーネント
  - [x] 1.1 `app/components/` ディレクトリ作成と InfoTooltipComponent / HelpTooltipComponent 実装
    - `app/components/info_tooltip_component.rb` + `app/components/info_tooltip_component.html.slim` を作成
    - `app/components/help_tooltip_component.rb` + `app/components/help_tooltip_component.html.slim` を作成
    - 必須パラメータ（label, description）が nil/blank の場合に `ArgumentError` を raise する初期化ロジック
    - `tabindex="0"`, `aria-label`, `aria-describedby` を含むアクセシブルな HTML 構造
    - CSS-only でホバー/フォーカス時にツールチップ表示（`:hover`, `:focus` 疑似クラス）
    - _Requirements: 1.1, 1.2, 1.6, 1.7, 1.8, 7.4_

  - [x] 1.2 StatusBadgeComponent 実装
    - `app/components/status_badge_component.rb` + `app/components/status_badge_component.html.slim` を作成
    - `status`, `label` 必須。`tooltip` はオプション
    - STATUS_CLASSES マッピング（draft, published, archived + unknown fallback）
    - tooltip 指定時はツールチップ要素を描画（`aria-describedby` 連携）
    - _Requirements: 1.4, 1.8, 4.2, 4.3_

  - [x] 1.3 EmptyStateComponent 実装
    - `app/components/empty_state_component.rb` + `app/components/empty_state_component.html.slim` を作成
    - `heading`, `description` 必須。`actions` slot（renders_many）
    - actions slot が空の場合は actions 領域を描画しない
    - _Requirements: 1.5, 1.8_

  - [x] 1.4 BreadcrumbComponent 実装
    - `app/components/breadcrumb_component.rb` + `app/components/breadcrumb_component.html.slim` を作成
    - `items` 配列（1件以上必須）。最終アイテムは `aria-current="page"` + リンクなし
    - 200文字超のラベルは `text-overflow: ellipsis` で切り詰め、`title` 属性にフルテキスト
    - `nav` 要素に `aria-label="パンくず"`
    - _Requirements: 2.1, 2.4, 2.5, 7.3_

  - [x] 1.5 PageHeaderComponent 実装
    - `app/components/page_header_component.rb` + `app/components/page_header_component.html.slim` を作成
    - `title` 必須、`subtitle` オプション。`breadcrumbs` slot（renders_one）、`actions` slot（renders_many）
    - `header` 要素で統一的に描画
    - _Requirements: 1.3, 1.8_

  - [x] 1.6 SectionNavComponent 実装
    - `app/components/section_nav_component.rb` + `app/components/section_nav_component.html.slim` を作成
    - `sections` 配列を受け取り、最大10件に制限
    - `role="tablist"` コンテナ、各タブに `role="tab"` + `aria-controls`
    - `data-controller="section-nav"` を付与
    - セクション 0 件時は描画しない（`render?` メソッド）
    - _Requirements: 3.1, 3.5, 3.7_

- [x] 2. Stimulus コントローラーと CSS
  - [x] 2.1 `section_nav_controller.ts` 実装
    - `app/frontend/controllers/section_nav_controller.ts` を新規作成
    - IntersectionObserver（rootMargin: "-0% 0% -70% 0%"）でアクティブセクション検出
    - タブクリックで smooth-scroll（sticky nav 高さ分オフセット）
    - `is-active` クラスと `aria-selected` 属性の切り替え
    - `application.ts` に controller 登録を追加
    - _Requirements: 3.2, 3.3, 3.4, 3.5_

  - [x] 2.2 CSS スタイル追加
    - ツールチップスタイル（`.info-tooltip`, `.help-tooltip` — `:hover`/`:focus` で表示）
    - セクションナビスタイル（`.section-nav` — sticky, z-index, max-height 48px, モバイル横スクロール）
    - ステータスバッジスタイル（`.status-badge` — draft/published/archived/unknown の色分け）
    - 空状態スタイル（`.empty-state` — 中央寄せ）
    - パンくずスタイル（`.breadcrumb-nav` — 区切り文字、ellipsis）
    - ページヘッダースタイル（`.page-header`）
    - モバイル対応（768px 未満でセクションナビ横スクロール + フェード表示）
    - _Requirements: 1.7, 3.2, 3.7_

- [x] 3. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. ヒーロー領域とビュー統合
  - [x] 4.1 DocumentsController#show にパンくず・セクションナビデータの組み立てを追加
    - `@hierarchy_breadcrumbs` 配列の組み立て（案件名 → 文書名 or 案件名 → 文書名 → 版ラベル）
    - `@section_nav_items` 配列の組み立て（本文有無、ロール、関連文書有無で動的に構成）
    - _Requirements: 2.2, 2.3, 3.6, 8.1, 8.2_

  - [x] 4.2 `show.html.slim` のヒーロー領域を PageHeaderComponent で統一
    - 2分岐していたヒーロー（`rendered_view_available` / else）を単一の PageHeaderComponent 呼び出しに統合
    - BreadcrumbComponent をパンくず slot に配置
    - StatusBadgeComponent で版ステータスを表示（tooltip 付き）
    - アクションボタンに HelpTooltipComponent を付与
    - 本文プレビュー有無の視覚インジケーター表示
    - External user 向けにアクションボタンを制限（内部操作を非表示）
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 4.3 `show.html.slim` に SectionNavComponent を配置
    - ヒーロー直下に SectionNavComponent を描画
    - 各セクションの `id` 属性と SectionNav の `aria-controls` を対応付け
    - 本文あり時は `details.document-context-drawer` 内のセクション、本文なし時はインライン表示のセクションに連動
    - _Requirements: 3.1, 3.2, 3.4, 8.1, 8.2_

- [x] 5. 属性パネルのセクション別カード化
  - [x] 5.1 `_detail_sections.html.slim` をセクション別カードに構造変更
    - 単一セクションから個別カード（属性、版一覧、関連文書、確認依頼）に分割
    - 各カードに `id` 属性を付与（`attributes`, `versions`, `related-documents`, `approval-requests`）
    - 属性セクションは `dl` 要素で描画（案件、カテゴリ、ファイル種、重要度、公開範囲、タグ）
    - カテゴリ・重要度・公開範囲に InfoTooltipComponent を付与
    - 出力時の扱いセクションに InfoTooltipComponent を付与
    - _Requirements: 5.1, 5.2, 5.3, 5.7, 5.8_

  - [x] 5.2 版一覧セクションに StatusBadgeComponent を適用
    - 各バージョンのステータスを StatusBadgeComponent で描画（tooltip 付き）
    - _Requirements: 5.4_

  - [x] 5.3 関連文書・確認依頼セクションに EmptyStateComponent を適用
    - 関連文書 0 件時: EmptyStateComponent（見出し + 説明 + 文書一覧リンク）
    - 確認依頼 0 件時: EmptyStateComponent（見出し + 説明 + 新規確認依頼リンク）
    - _Requirements: 5.5, 5.6_

- [x] 6. コメントワークスペースの改善
  - [x] 6.1 FAB に未解決件数バッジを追加
    - `_comment_workspace.html.slim` の FAB 要素にカウントバッジを描画
    - 0 件時はバッジ非表示、99 超は "99+" 表示
    - Internal admin: Q&A 未解決 + 確認事項未解決、External user: Q&A 未解決のみ
    - _Requirements: 6.1, 6.2_

  - [x] 6.2 コメントワークスペースにツールチップと EmptyState を追加
    - 各タブラベルに InfoTooltipComponent（すべて/Q&A/確認事項/未解決の説明）
    - コメントモードスイッチに HelpTooltipComponent（質問 vs 確認事項の違い）
    - アクティブタブの結果 0 件時に EmptyStateComponent を描画
    - セクション要素に `id="comments"` を付与
    - _Requirements: 6.3, 6.4, 6.5, 6.6_

- [x] 7. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. 画面状態パターンの表示制御
  - [x] 8.1 本文あり/なし分岐のレイアウト制御を整理
    - 本文あり: iframe viewer + drawer + floating comment workspace
    - 本文なし: attribute panel inline + inline comment workspace
    - セクションナビの「本文」タブ有無を `@viewer_iframe_src` で制御
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 8.2 ロール別表示制御の確認・調整
    - External user: 確認事項タブ、確認事項投稿フォーム、確認依頼、ドラッグ＆ドロップ、handoff summary を非表示
    - Internal admin: 全管理セクション表示、iframe 上のドラッグ＆ドロップ有効
    - _Requirements: 8.4, 8.5, 8.6_

- [x] 9. テスト
  - [x] 9.1 ViewComponent ユニットテスト作成
    - 全7コンポーネント（InfoTooltip, HelpTooltip, PageHeader, StatusBadge, EmptyState, Breadcrumb, SectionNav）の `render_inline` テスト
    - 正常系レンダリング、必須パラメータ欠落時の ArgumentError、slot の描画確認
    - パンくず: デフォルト階層構造、版指定時構造、200文字超truncate
    - セクションナビ: 本文なし時のタブ除外、10件超制限
    - _Requirements: 1.1–1.8, 2.2, 2.3, 2.5, 3.6, 4.2, 5.1, 5.5, 5.6, 6.3, 6.4_

  - [ ]* 9.2 Property-based テスト: Tooltip accessibility invariant (Property 1)
    - **Property 1: Tooltip accessibility invariant**
    - ランダムな description 文字列で InfoTooltipComponent / HelpTooltipComponent を描画し、tabindex="0" + aria-label + aria-describedby の存在を検証
    - **Validates: Requirements 1.1, 1.2, 1.6, 7.4**

  - [ ]* 9.3 Property-based テスト: Required parameter validation (Property 2)
    - **Property 2: Required parameter validation**
    - 各コンポーネントに nil/blank の必須パラメータを渡して ArgumentError が raise されることを検証
    - **Validates: Requirements 1.8**

  - [ ]* 9.4 Property-based テスト: Breadcrumb final item invariant (Property 3)
    - **Property 3: Breadcrumb final item invariant**
    - ランダムな items 配列で BreadcrumbComponent を描画し、最終アイテムが aria-current="page" かつリンクなしであることを検証
    - **Validates: Requirements 2.4**

  - [ ]* 9.5 Property-based テスト: Breadcrumb label truncation (Property 4)
    - **Property 4: Breadcrumb label truncation**
    - 200文字超のラベルを含む items で描画し、truncate と title 属性を検証
    - **Validates: Requirements 2.5**

  - [ ]* 9.6 Property-based テスト: Section nav tab limit (Property 5)
    - **Property 5: Section nav tab limit**
    - 10件超の sections で描画し、出力タブが最大10件であることを検証
    - **Validates: Requirements 3.1**

  - [ ]* 9.7 Property-based テスト: Section nav ARIA roles (Property 6)
    - **Property 6: Section nav ARIA roles**
    - ランダムな sections で描画し、role="tablist" + role="tab" + aria-controls の整合性を検証
    - **Validates: Requirements 3.5**

  - [ ]* 9.8 Property-based テスト: StatusBadge tooltip presence (Property 7)
    - **Property 7: StatusBadge tooltip presence**
    - tooltip パラメータありで StatusBadgeComponent を描画し、tooltip 要素と aria-describedby の存在を検証
    - **Validates: Requirements 4.3, 5.4**

  - [ ]* 9.9 Property-based テスト: FAB badge display logic (Property 8)
    - **Property 8: FAB badge display logic**
    - ランダムな整数 unresolved count に対して、バッジ表示/非表示と "99+" 制限を検証
    - **Validates: Requirements 6.1, 6.2**

  - [ ]* 9.10 Property-based テスト: External user section exclusion (Property 9)
    - **Property 9: External user section exclusion**
    - External user として documents#show をレンダリングし、内部限定セクションが含まれないことを検証
    - **Validates: Requirements 4.7, 8.4**

  - [ ]* 9.11 Property-based テスト: Attribute panel section id uniqueness (Property 10)
    - **Property 10: Attribute panel section id uniqueness**
    - 属性パネル描画時に全セクション id が一意かつ SectionNav の aria-controls と対応することを検証
    - **Validates: Requirements 5.2**

  - [ ]* 9.12 Property-based テスト: Navigation aria-label in Japanese (Property 11)
    - **Property 11: Navigation aria-label in Japanese**
    - ナビゲーション要素の aria-label が日本語テキストであることを検証
    - **Validates: Requirements 7.3**

  - [x] 9.13 Request spec: documents#show のロール別表示・状態パターン
    - Internal admin が全セクション閲覧可能
    - External user が内部限定セクション閲覧不可
    - 版指定なし / 版指定ありでのパンくず変化（構造アサーション）
    - 本文あり / なしでのレイアウト分岐（drawer 有無、comment workspace mode）
    - _Requirements: 4.7, 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 10. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties（`rantly` gem 使用）
- Unit tests validate specific examples and edge cases
- `app/components/` ディレクトリは新規作成が必要
- 新規 Stimulus controller は TypeScript で作成し `application.ts` に登録
- CSS は既存 `application.css` に追加スタイルとして拡張
- 全 UI テキストは日本語で実装

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3", "1.4"] },
    { "id": 1, "tasks": ["1.2", "1.5", "1.6"] },
    { "id": 2, "tasks": ["2.1", "2.2"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3", "5.1"] },
    { "id": 5, "tasks": ["5.2", "5.3", "6.1"] },
    { "id": 6, "tasks": ["6.2", "8.1"] },
    { "id": 7, "tasks": ["8.2"] },
    { "id": 8, "tasks": ["9.1", "9.13"] },
    { "id": 9, "tasks": ["9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "9.10", "9.11", "9.12"] }
  ]
}
```
