# frozen_string_literal: true

module AccessibleDocumentsHelper
  ACCESSIBLE_DOCUMENT_BOOLEAN_FILTER_LABELS = {
    has_html: "HTML生成済み",
    has_files: "添付あり",
    has_pdf: "PDFあり",
    has_diagram: "図あり"
  }.freeze

  def accessible_document_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 180, pinned: true, overflow: :ellipsis),
      table_preferences_column(:document, label: "文書名", default_width: 240, pinned: true, overflow: :ellipsis),
      table_preferences_column(:match_reason, label: "ヒット理由", default_width: 240, overflow: :ellipsis),
      table_preferences_column(:tags, label: "タグ", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 120),
      table_preferences_column(:document_kind, label: "ファイル種", default_width: 120),
      table_preferences_column(:importance_level, label: "重要度", default_width: 120),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 140),
      table_preferences_column(:latest_version, label: "最新版", default_width: 120),
      table_preferences_column(:html, label: "HTML", default_width: 100),
      table_preferences_column(:files, label: "添付", default_width: 100),
      table_preferences_column(:updated_at, label: "最終更新", default_width: 160, sortable: true)
    ]
  end

  def accessible_document_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def accessible_document_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: accessible_document_project_option_label(project) }
  end

  def accessible_document_active_filter_labels(filters, available_tags: [], selected_project: nil)
    labels = []
    normalized_filters = filters.to_h.symbolize_keys

    keyword = normalized_filters[:q].to_s.squish
    labels << "キーワード: #{keyword}" if keyword.present?

    if selected_project.present?
      labels << "案件: #{accessible_document_project_option_label(selected_project)}"
    end

    tag_label = accessible_document_tag_filter_label(normalized_filters[:tag], available_tags)
    labels << "タグ: #{tag_label}" if tag_label.present?

    labels.concat(accessible_document_enum_filter_labels(normalized_filters))

    ACCESSIBLE_DOCUMENT_BOOLEAN_FILTER_LABELS.each do |key, label|
      labels << label if ActiveModel::Type::Boolean.new.cast(normalized_filters[key])
    end

    labels
  end

  private

  def accessible_document_tag_filter_label(value, available_tags)
    normalized_tag = DocumentTag.normalize(value)
    return if normalized_tag.blank?

    tag = available_tags.find { |candidate| candidate.normalized_name == normalized_tag }
    tag&.name || value.to_s.strip
  end

  def accessible_document_enum_filter_labels(filters)
    [
      accessible_document_enum_filter_label(filters, :category, "カテゴリ", Document.categories, "documents.category"),
      accessible_document_enum_filter_label(filters, :document_kind, "ファイル種", Document.document_kinds, "documents.document_kind"),
      accessible_document_enum_filter_label(filters, :visibility_policy, "公開範囲", Document.visibility_policies, "documents.visibility_policy")
    ].compact
  end

  def accessible_document_enum_filter_label(filters, key, label, values, scope)
    value = filters[key].to_s
    return if value.blank? || !values.key?(value)

    "#{label}: #{localized_label(scope, value)}"
  end
end
