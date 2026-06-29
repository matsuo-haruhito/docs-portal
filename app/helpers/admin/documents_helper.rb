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
      table_preferences_column(:legacy_versions, label: "古い版候補", default_width: 260),
      table_preferences_column(:retention_until, label: "保管期限", default_width: 120),
      table_preferences_column(:discard_candidate_at, label: "廃棄候補", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end

  def admin_document_active_filter_summaries(filters)
    filters = filters.to_h.with_indifferent_access

    [
      admin_document_text_filter_summary("キーワード", filters[:q]),
      admin_document_option_filter_summary("カテゴリ", filters[:category], admin_document_category_filter_options),
      admin_document_option_filter_summary("種別", filters[:document_kind], admin_document_kind_filter_options),
      admin_document_option_filter_summary("公開範囲", filters[:visibility_policy], admin_document_visibility_filter_options),
      admin_document_option_filter_summary("アーカイブ状態", filters[:archived], admin_document_archived_filter_options),
      admin_document_option_filter_summary("保管期限", filters[:retention], admin_document_retention_filter_options),
      admin_document_option_filter_summary("廃棄候補", filters[:discard], admin_document_discard_filter_options)
    ].compact
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

  def admin_document_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def admin_document_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: admin_document_project_option_label(project) }
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

  def admin_document_legacy_versions(document)
    document.document_versions.to_a
      .reject { |version| version.id == document.latest_version_id }
      .sort_by { |version| [version.updated_at || Time.zone.at(0), version.id || 0] }
      .reverse
  end

  def admin_document_legacy_version_source_label(version)
    labels = []
    labels << "manual upload由来の可能性" if version.version_label.to_s.start_with?("manual-")

    source_path = version.source_relative_path.presence || [version.source_directory, version.source_file_name].compact_blank.join("/").presence
    labels << "source: #{source_path}" if source_path.present?

    labels.presence&.join(" / ") || "source未設定"
  end

  private

  def admin_document_text_filter_summary(label, value)
    value = value.to_s.strip
    return if value.blank?

    "#{label}: #{value}"
  end

  def admin_document_option_filter_summary(label, value, options)
    return if value.blank?

    selected_option = options.find { |(_, option_value)| option_value.to_s == value.to_s }
    display = selected_option ? selected_option.first : "指定あり"
    "#{label}: #{display}"
  end
end
