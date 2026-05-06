class DocumentsController < BaseController
  before_action :apply_rparam, only: :index

  DOCUMENTS_PER_PAGE = 20
  DIAGRAM_EXTENSIONS = %w[puml plantuml d2 mmd mermaid].freeze

  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @filters = document_filter_params
    @available_tags = DocumentTag
      .joins(:documents)
      .merge(@project.documents.accessible_to(current_user))
      .ordered
      .distinct

    documents_scope = filtered_documents.recommended_first.includes(:latest_version, :document_tags, :document_keywords, document_versions: :document_files)
    visible_documents = current_user.internal? ? documents_scope.to_a : documents_scope.to_a.select { _1.visible_in_portal_for?(current_user) }
    @documents_count = visible_documents.size
    @current_page = normalized_page
    @per_page = DOCUMENTS_PER_PAGE
    @total_pages = [(@documents_count.to_f / @per_page).ceil, 1].max
    @current_page = @total_pages if @current_page > @total_pages

    @documents = visible_documents.slice((@current_page - 1) * @per_page, @per_page) || []
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def show
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @document = @project.documents.includes(:document_tags, :document_keywords).find_by!(slug: params[:slug])
    require_document_access!(@document)

    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    raise ApplicationError::Forbidden if !current_user.internal? && @versions.empty?

    @latest_viewable_version = @document.latest_version if @document.latest_version && @versions.include?(@document.latest_version)
    @source_breadcrumbs = SourcePathBreadcrumb.new(
      document: @document,
      version: @latest_viewable_version || @versions.first,
      project: @project
    ).crumbs
    @related_document_groups = RelatedDocumentFinder.new(document: @document, user: current_user).grouped_results
    visible_comments = @document.document_review_comments.visible_to(current_user)
    @question_threads = visible_comments.where(internal_only: false, comment_type: :question).roots.includes(:author, :resolved_by, :document_version, replies: [:author, :resolved_by]).order(:created_at, :id)
    @review_comments = visible_comments.where(internal_only: true).includes(:author, :resolved_by, :document_version).roots.order(:created_at, :id)
    @export_preview_file = export_preview_files.first
    @export_watermark_text =
      if @export_preview_file.present?
        ExportOutputPlan.new(project: @project, viewer: current_user, files: [@export_preview_file], include_source_path: false).call.items.first.watermark_text
      end
    @document_approval_requests =
      if current_user.internal?
        @document.document_approval_requests.recent_first.limit(5).includes(:requester, :approver)
      else
        DocumentApprovalRequest.none
      end
    @approval_approvers = User.where(user_type: :internal, active: true).order(:name, :email_address)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  private

  def export_preview_files
    @export_preview_files ||= @versions.flat_map(&:document_files).select { _1.downloadable_by?(current_user) }.select do |file|
      file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
    end
  end

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
    params.to_unsafe_h.symbolize_keys.slice(*DocumentsParameter::INDEX_FILTERS)
  end

  def normalized_page
    @filters[:page]
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
    file_name_patterns = DIAGRAM_EXTENSIONS.map { "%.#{_1}" }

    scope
      .left_joins(document_versions: :document_files)
      .where(
        ["document_versions.source_extension IN (?) OR #{file_name_sql}", DIAGRAM_EXTENSIONS, *file_name_patterns]
      )
  end

  def enabled_filter?(key)
    @filters[key] == true
  end
end
