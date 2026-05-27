class ProjectDocumentFilter
  FILTER_KEYS = %i[q tag category document_kind visibility_policy has_html has_files has_pdf has_diagram].freeze
  DIAGRAM_EXTENSIONS = %w[puml plantuml d2 mmd mermaid].freeze

  def initialize(project:, user:, filters:)
    @project = project
    @user = user
    @filters = filters.to_h.symbolize_keys.slice(*FILTER_KEYS)
  end

  def call
    scope = @project.documents.accessible_to(@user)
    scope = DocumentSearch.new(@filters[:q]).apply(scope)
    scope = apply_tag_filter(scope)
    scope = apply_enum_filter(scope, :category, Document.categories)
    scope = apply_enum_filter(scope, :document_kind, Document.document_kinds)
    scope = apply_enum_filter(scope, :visibility_policy, Document.visibility_policies)
    scope = apply_availability_filters(scope)
    scope.distinct
  end

  private

  def apply_tag_filter(scope)
    tag = @filters[:tag].to_s.strip
    return scope if tag.blank?

    scope
      .joins(:document_tags)
      .where(document_tags: { normalized_name: DocumentTag.normalize(tag) })
  end

  def apply_enum_filter(scope, key, enum_values)
    value = @filters[key].to_s
    return scope if value.blank? || !enum_values.key?(value)

    scope.where(key => value)
  end

  def apply_availability_filters(scope)
    scope = filter_html_available(scope) if enabled_filter?(:has_html)
    scope = filter_file_attached(scope) if enabled_filter?(:has_files)
    scope = filter_pdf_available(scope) if enabled_filter?(:has_pdf)
    scope = filter_diagram_available(scope) if enabled_filter?(:has_diagram)
    scope
  end

  def filter_html_available(scope)
    html_version_ids = DocumentVersion.where.not(site_build_path: [nil, ""]).select(:id)
    scope.where(latest_version_id: html_version_ids)
  end

  def filter_file_attached(scope)
    document_ids = DocumentVersion.joins(:document_files).select(:document_id)
    scope.where(id: document_ids)
  end

  def filter_pdf_available(scope)
    scope
      .left_joins(document_versions: :document_files)
      .where(
        "documents.document_kind = :pdf_kind OR LOWER(document_files.file_name) LIKE :pdf_file_name",
        pdf_kind: Document.document_kinds[:pdf],
        pdf_file_name: "%.pdf"
      )
  end

  def filter_diagram_available(scope)
    file_name_sql = DIAGRAM_EXTENSIONS.map { "LOWER(document_files.file_name) LIKE ?" }.join(" OR ")
    file_name_patterns = DIAGRAM_EXTENSIONS.map { |extension| "%.#{extension}" }

    scope
      .left_joins(document_versions: :document_files)
      .where(
        ["document_versions.source_extension IN (?) OR #{file_name_sql}", DIAGRAM_EXTENSIONS, *file_name_patterns]
      )
  end

  def enabled_filter?(key)
    ActiveModel::Type::Boolean.new.cast(@filters[key])
  end
end
