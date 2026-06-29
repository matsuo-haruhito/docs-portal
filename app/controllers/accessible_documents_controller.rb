class AccessibleDocumentsController < BaseController
  before_action :apply_rparam, only: :index

  DOCUMENTS_PER_PAGE = 20
  DIAGRAM_EXTENSIONS = %w[puml plantuml d2 mmd mermaid].freeze
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  def index
    @filters = document_filter_params
    @selected_project = selected_filter_project
    if @selected_project
      @filters[:project_id] = @selected_project.id
    else
      @filters.delete(:project_id)
    end

    accessible_scope = Document.accessible_to(current_user)
    @available_tags = DocumentTag
      .joins(:documents)
      .merge(accessible_scope)
      .ordered
      .distinct

    documents_scope = filtered_documents(visible_documents_scope)
      .recommended_first
      .order(updated_at: :desc)

    @documents_count = documents_scope.count
    @current_page = normalized_page
    @per_page = DOCUMENTS_PER_PAGE
    @total_pages = [(@documents_count.to_f / @per_page).ceil, 1].max
    @current_page = @total_pages if @current_page > @total_pages
    @documents = documents_scope
      .includes(:project, :latest_version, :document_tags, :document_keywords, document_versions: :document_files)
      .offset((@current_page - 1) * @per_page)
      .limit(@per_page)
      .to_a
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = accessible_project_scope.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def filtered_documents(scope)
    scope = apply_project_filter(scope)
    scope = apply_keyword_filter(scope)
    scope = apply_tag_filter(scope)
    scope = apply_enum_filter(scope, :category, Document.categories)
    scope = apply_enum_filter(scope, :document_kind, Document.document_kinds)
    scope = apply_enum_filter(scope, :visibility_policy, Document.visibility_policies)
    scope = apply_availability_filters(scope)
    scope.distinct
  end

  def document_filter_params
    params.to_unsafe_h.symbolize_keys.slice(*DocumentsParameter::INDEX_FILTERS, :project_id)
  end

  def normalized_page
    @filters[:page].to_i.clamp(1, Float::INFINITY)
  end

  def visible_documents_scope
    Document.portal_visible_to(current_user)
  end

  def accessible_project_scope
    Project.where(id: visible_documents_scope.select(:project_id)).order(:code, :id)
  end

  def selected_filter_project
    return if params[:project_id].blank?

    accessible_project_scope.find_by(id: params[:project_id])
  end

  def searchable_projects
    scope = accessible_project_scope
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.accessible_document_project_option_label(project) }
  end

  def apply_project_filter(scope)
    return scope if @selected_project.blank?

    scope.where(project_id: @selected_project.id)
  end

  def apply_keyword_filter(scope)
    DocumentSearch.new(@filters[:q]).apply(scope)
  end

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
