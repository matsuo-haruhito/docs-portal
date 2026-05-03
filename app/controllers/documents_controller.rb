class DocumentsController < BaseController
  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @filters = document_filter_params
    @available_tags = DocumentTag
      .joins(:documents)
      .merge(@project.documents.accessible_to(current_user))
      .ordered
      .distinct
    @documents = filtered_documents
      .includes(:latest_version, :document_tags, :document_keywords, document_versions: :document_files)
      .order(:title)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def show
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @document = @project.documents.includes(:document_tags, :document_keywords).find_by!(slug: params[:slug])
    require_document_access!(@document)

    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @related_document_groups = RelatedDocumentFinder.new(document: @document, user: current_user).grouped_results
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  private

  def filtered_documents
    scope = @project.documents.accessible_to(current_user)
    scope = apply_keyword_filter(scope)
    scope = apply_tag_filter(scope)
    scope = apply_enum_filter(scope, :category, Document.categories)
    scope = apply_enum_filter(scope, :document_kind, Document.document_kinds)
    scope = apply_enum_filter(scope, :visibility_policy, Document.visibility_policies)
    scope = apply_availability_filters(scope)
    scope.distinct
  end

  def document_filter_params
    params.permit(:q, :tag, :category, :document_kind, :visibility_policy, :has_html, :has_files, :has_pdf)
  end

  def apply_keyword_filter(scope)
    keyword = @filters[:q].to_s.strip
    return scope if keyword.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
    normalized_pattern = "%#{ActiveRecord::Base.sanitize_sql_like(DocumentKeyword.normalize(keyword))}%"

    scope
      .left_joins(:document_keywords, document_versions: :document_files)
      .where(
        "documents.title ILIKE :pattern OR " \
        "documents.slug ILIKE :pattern OR " \
        "document_versions.version_label ILIKE :pattern OR " \
        "document_files.file_name ILIKE :pattern OR " \
        "document_keywords.keyword ILIKE :pattern OR " \
        "document_keywords.normalized_keyword LIKE :normalized_pattern",
        pattern:,
        normalized_pattern:
      )
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

  def enabled_filter?(key)
    ActiveModel::Type::Boolean.new.cast(@filters[key])
  end
end
