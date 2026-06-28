class DocumentsController < BaseController
  before_action :apply_rparam, only: :index

  helper_method :safe_return_to, :approved_upload_handoff_version

  DOCUMENTS_PER_PAGE = 20

  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @filters = document_filter_params
    @selected_source_path = selected_source_path
    @zip_source_path = zip_source_path
    @uploaded_version = uploaded_version_for_confirmation
    @available_tags = DocumentTag
      .joins(:documents)
      .merge(@project.documents.accessible_to(current_user))
      .ordered
      .distinct

    documents_scope = filtered_documents.recommended_first.includes(:latest_version, :document_tags, :document_keywords, document_versions: :document_files)
    visible_documents = current_user.internal? ? documents_scope.to_a : documents_scope.to_a.select { |document| document.visible_in_portal_for?(current_user) }
    @documents_count = visible_documents.size
    @selectable_documents_count = visible_documents.count do |document|
      document.latest_version.present? && document.downloadable_by?(current_user) && document.latest_version.viewable_by?(current_user)
    end
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

    @document = find_document_or_redirect_from_historical_slug
    return if performed?

    require_document_access!(@document)
    raise ApplicationError::Forbidden unless current_user.internal? || @document.visible_in_portal_for?(current_user)

    @versions = @document.document_versions.includes(:document_files).select { |version| version.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @latest_viewable_version = @document.latest_version if @document.latest_version && @versions.include?(@document.latest_version)
    @viewer_version = resolved_viewer_version
    @path_history_resolution = resolve_path_history
    return redirect_to_canonical_site_path if @path_history_resolution&.moved?

    mark_document_as_read!(@document, @viewer_version)
    @viewer_site_path = @path_history_resolution&.canonical_path.presence || params[:site_path].presence || @viewer_version&.html_view_site_path
    @previous_site_path = params[:previous_site_path].presence
    @previous_slug = params[:previous_slug].presence
    @terminal_slug_history_resolution = @slug_history_resolution if @slug_history_resolution&.terminal?
    @terminal_path_history_resolution = resolve_terminal_path_history || (@path_history_resolution if @path_history_resolution&.terminal?)
    @viewer_iframe_src = embedded_viewer_src(@viewer_version)
    @viewer_popout_src = @viewer_iframe_src
    @source_breadcrumbs = SourcePathBreadcrumb.new(
      document: @document,
      version: @latest_viewable_version || @versions.first,
      project: @project
    ).crumbs
    @related_document_groups = RelatedDocumentFinder.new(document: @document, user: current_user).grouped_results
    visible_comments = @document.document_review_comments.visible_to(current_user)
    comment_author_candidates = visible_comments.includes(:author).map(&:author)
    comment_search = DocumentCommentWorkspaceSearch.new(
      user: current_user,
      query: params[:comment_q],
      author_public_id: params[:comment_author_id],
      author_candidates: comment_author_candidates
    )
    question_threads = visible_comments.where(internal_only: false, comment_type: :question).roots.includes(:author, :resolved_by, :document_version, replies: [:author, :resolved_by]).order(:created_at, :id)
    review_comments = visible_comments.where(internal_only: true).includes(:author, :resolved_by, :document_version).roots.order(:created_at, :id)
    @question_threads = comment_search.filter_questions(question_threads)
    @review_comments = comment_search.filter_reviews(review_comments)
    @comment_search_query = comment_search.query
    @comment_author_options = comment_search.author_options
    @comment_author_id = comment_search.public_id
    @comment_selected_author = comment_search.selected_author
    @comment_workspace_tab = DocumentCommentWorkspaceTab.new(user: current_user, tab: params[:comment_tab]).value
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

  def find_document_or_redirect_from_historical_slug
    document = @project.documents.includes(:document_tags, :document_keywords).find_by(slug: params[:slug])
    return document if document

    @slug_history_resolution = DocumentSlugHistoryResolver.new(project: @project, requested_slug: params[:slug]).call
    raise ActiveRecord::RecordNotFound, "Document not found" if @slug_history_resolution.missing?

    return @slug_history_resolution.canonical_document if @slug_history_resolution.terminal?

    redirect_to_canonical_document_slug(@slug_history_resolution)
    nil
  end

  def redirect_to_canonical_document_slug(slug_resolution)
    redirect_params = request.query_parameters.merge(previous_slug: slug_resolution.requested_slug)
    redirect_to project_document_path(@project, slug_resolution.canonical_document.slug, redirect_params), status: :found
  end

  def resolve_path_history
    return unless @viewer_version

    DocumentPathHistoryResolver.new(
      document: @document,
      requested_site_path: params[:site_path].presence,
      canonical_version: @viewer_version,
      candidate_versions: @versions
    ).call
  end

  def resolve_terminal_path_history
    return if params[:terminal_site_path].blank? || @viewer_version.blank?

    resolution = DocumentPathHistoryResolver.new(
      document: @document,
      requested_site_path: params[:terminal_site_path],
      canonical_version: @viewer_version,
      candidate_versions: @versions
    ).call
    resolution if resolution.terminal?
  end

  def redirect_to_canonical_site_path
    redirect_params = request.query_parameters.merge(
      version_id: @path_history_resolution.canonical_version.public_id,
      site_path: @path_history_resolution.canonical_path,
      previous_site_path: @path_history_resolution.requested_path
    )
    redirect_to project_document_path(@project, @document.slug, redirect_params), status: :found
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

  def approved_upload_handoff_version
    approved_public_id = flash[:approved_upload_version_public_id].presence
    return unless approved_public_id && current_user.internal?
    return unless @viewer_version&.public_id == approved_public_id
    return unless @document.latest_version_id == @viewer_version.id
    return unless @viewer_version.source_commit_hash == ManualDocumentUploadReview::MANUAL_UPLOAD_SOURCE

    @viewer_version
  end

  def export_preview_files
    @export_preview_files ||= @versions.flat_map(&:document_files).select { |file| file.downloadable_by?(current_user) }.select do |file|
      file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
    end
  end

  def filtered_documents
    ProjectDocumentFilter.new(project: @project, user: current_user, filters: @filters).call
  end

  def portal_tree_projects(include_project: nil)
    projects = Project.accessible_to(current_user).order(:code)
    return projects.includes(documents: :latest_version) if current_user.internal?

    visible_projects = projects
      .with_portal_visible_documents_for(current_user)
      .includes(documents: [:latest_version, :document_versions])
      .select { |project| visible_project_for_portal?(project) }
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
    @filters[:page].to_i.clamp(1, Float::INFINITY)
  end

  def selected_source_path
    zip_source_path || query_source_path_candidate
  end

  def zip_source_path
    normalize_source_path_param(params[:upload_source_path].presence)
  end

  def query_source_path_candidate
    query = @filters[:q].to_s.strip
    return if query.blank? || query.exclude?("/")

    normalize_source_path_param(query)
  end

  def normalize_source_path_param(value)
    return if value.blank?

    normalized = value.to_s.tr("\\", "/").delete_prefix("/")
    return if normalized.blank? || normalized.include?("*") || normalized.include?("?")
    return if normalized == "." || normalized == ".." || normalized.start_with?("../")

    normalized
  end

  def safe_return_to(fallback = project_documents_path(@project))
    path = params[:return_to].to_s
    return fallback unless path.start_with?("/")
    return fallback if path.start_with?("//")

    path
  end

  def uploaded_version_for_confirmation
    return if params[:uploaded_version_id].blank?

    DocumentVersion.includes(:document).find_by(public_id: params[:uploaded_version_id]).tap do |version|
      return unless version&.document&.project_id == @project.id
      return unless version.viewable_by?(current_user)
    end
  end
end