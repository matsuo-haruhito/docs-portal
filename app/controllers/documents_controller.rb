class DocumentsController < BaseController
  before_action :apply_rparam, only: :index

  DOCUMENTS_PER_PAGE = 20
  DIAGRAM_EXTENSIONS = %w[puml plantuml d2 mmd mermaid].freeze

  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @filters = document_filter_params
    @selected_source_path = selected_source_path
    @uploaded_version = uploaded_version_for_confirmation
    @available_tags = DocumentTag
      .joins(:documents)
      .merge(@project.documents.accessible_to(current_user))
      .ordered
      .distinct

    documents_scope = filtered_documents.recommended_first.includes(:latest_version, :document_tags, :document_keywords, document_versions: :document_files)
    visible_documents = current_user.internal? ? documents_scope.to_a : documents_scope.to_a.select { |document| document.visible_in_portal_for?(current_user) }
    @documents_count = visible_documents.size
    @current_page = normalized_page
    @per_page = DOCUMENTS_PER_PAGE
    @total_pages = [(@documents_count.to_f / @per_page).ceil, 1].max
    @current_page = @total_pages if @current_page > @total_pages

    @documents = visible_documents.slice((@current_page - 1) * @per_page, @per_page) || []
    @tree_projects = portal_tree_projects(include_project: @project)
  end

  def show
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @document = @project.documents.includes(:document_tags, :document_keywords).find_by!(slug: params[:slug])
    require_document_access!(@document)
    raise ApplicationError::Forbidden unless current_user.internal? || @document.visible_in_portal_for?(current_user)

    @versions = @document.document_versions.includes(:document_files).select { |version| version.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @latest_viewable_version = @document.latest_version if @document.latest_version && @versions.include?(@document.latest_version)
    @viewer_version = resolved_viewer_version
    mark_document_as_read!(@document, @viewer_version)
    @viewer_site_path = params[:site_path].presence || @viewer_version&.html_view_site_path
    @viewer_iframe_src = embedded_viewer_src(@viewer_version)
    @viewer_popout_src = @viewer_iframe_src
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
    @tree_projects = portal_tree_projects(include_project: @project)
  end

  private

  def embedded_viewer_src(version)
    return unless version

    if version.rendered_site_available?
      project_site_path(@project, site_path: @viewer_site_path, version_id: version.public_id, embedded: "1")
    elsif (file = version.embedded_view_file)
      document_file_path(file, disposition: "inline", embedded: "1")
    end
  end

  def mark_document_as_read!(document, document_version)
    current_user.read_confirmations.find_or_initialize_by(document:).tap do |confirmation|
      confirmation.document_version = document_version || document.latest_version
      confirmation.confirmed_at = Time.current
      confirmation.save!
    end
  end

  def resolved_viewer_version
    requested_public_id = params[:version_id].presence
    return @latest_viewable_version || @versions.first if requested_public_id.blank?

    version = @versions.find { |candidate| candidate.public_id == requested_public_id }
    raise ActiveRecord::RecordNotFound, "Document version not found" unless version

    version
  end

  def export_preview_files
    @export_preview_files ||= @versions.flat_map(&:document_files).select { |file| file.downloadable_by?(current_user) }.select do |file|
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

  def portal_tree_projects(include_project: nil)
    projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
    return projects if current_user.internal?

    visible_projects = projects.select { |project| visible_project_for_portal?(project) }
    visible_projects << include_project if include_project.present? && visible_projects.exclude?(include_project)
    visible_projects
  end

  def visible_project_for_portal?(project)
    project.documents.any? { |document| document.visible_in_portal_for?(current_user) }
  end

  def document_filter_params
    params.to_unsafe_h.symbolize_keys.slice(*DocumentsParameter::INDEX_FILTERS)
  end

  def normalized_page
    @filters[:page]
  end

  def selected_source_path
    normalize_source_path_param(params[:upload_source_path].presence)
  end

  def normalize_source_path_param(value)
    return if value.blank?

    normalized = value.to_s.tr("\\", "/").delete_prefix("/")
    return if normalized.blank? || normalized.include?("*") || normalized.include?("?")
    return if normalized == "." || normalized == ".." || normalized.start_with?("../")

    normalized
  end

  def uploaded_version_for_confirmation
    return if params[:uploaded_version_id].blank?

    DocumentVersion.includes(:document).find_by(public_id: params[:uploaded_version_id]).tap do |version|
      return unless version&.document&.project_id == @project.id
      return unless version.viewable_by?(current_user)
    end
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
    @filters[key] == true
  end
end