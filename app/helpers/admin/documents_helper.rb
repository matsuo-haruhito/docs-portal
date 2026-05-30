# frozen_string_literal: true

module Admin::DocumentsHelper
  def document_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:title, label: "文書名", default_width: 260, overflow: :ellipsis, sortable: true),
      table_preferences_column(:slug, label: "URL識別子", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 140),
      table_preferences_column(:document_kind, label: "種別", default_width: 120),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 140),
      table_preferences_column(:status, label: "状態", default_width: 170),
      table_preferences_column(:latest_version, label: "最新版/HTML", default_width: 190),
      table_preferences_column(:retention_until, label: "保管期限", default_width: 120),
      table_preferences_column(:discard_candidate_at, label: "廃棄候補", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end

  def admin_document_category_filter_options
    [["すべて", ""]] + Document.categories.keys.map { |key| [localized_label("documents.category", key), key] }
  end

  def admin_document_kind_filter_options
    [["すべて", ""]] + Document.document_kinds.keys.map { |key| [localized_label("documents.document_kind", key), key] }
  end

  def admin_document_visibility_filter_options
    [["すべて", ""]] + Document.visibility_policies.keys.map { |key| [localized_label("documents.visibility_policy", key), key] }
  end

  def admin_document_archived_filter_options
    [["すべて", ""], ["有効のみ", "active"], ["アーカイブ済みのみ", "archived"]]
  end

  def admin_document_retention_filter_options
    [["すべて", ""], ["保管期限あり", "set"], ["保管期限なし", "missing"], ["保管期限切れ", "due"]]
  end

  def admin_document_discard_filter_options
    [["すべて", ""], ["廃棄候補あり", "set"], ["廃棄候補なし", "missing"], ["廃棄候補期限切れ", "due"]]
  end

  def admin_document_project_secondary_label(project)
    project.code.presence
  end

  def admin_document_latest_version_preview_label(version)
    return "HTML未生成" if version.blank?
    return "HTML表示可" if version.rendered_site_available?
    return "プレビュー失敗" if version.preview_failed?
    return "プレビュー生成中" if version.preview_queued? || version.preview_running?
    return "HTML未確認" if version.preview_succeeded?

    "HTML未生成"
  end

  def admin_document_latest_version_publication_label(version)
    return "公開版なし" if version.blank?
    return document_version_status_label(version) unless version.published?

    case version.publication_window_state
    when :not_started
      "公開前"
    when :expired
      "公開終了"
    else
      "公開期間中"
    end
  end
end