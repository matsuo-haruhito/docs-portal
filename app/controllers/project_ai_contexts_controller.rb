class ProjectAiContextsController < BaseController
  before_action :set_project

  PREVIEW_DOCUMENT_LIMIT = 50
  DOCUMENT_QUERY_MAX_LENGTH = AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH

  helper_method :document_query_max_length

  def show
    @mode = requested_mode
    return render_unsupported_mode unless @mode

    @requested_document_ids = requested_document_ids
    @scope = requested_scope
    @scoped_document_count = scoped_document_count
    @unscoped_document_count = @requested_document_ids.size - @scoped_document_count
    @document_query = normalized_document_query
    @candidate_view = requested_candidate_view
    selectable_documents_all = selectable_documents
    @selectable_document_total_count = selectable_documents_all.size
    @matching_selectable_documents = filtered_selectable_documents(selectable_documents_all)
    @matching_selectable_document_count = @matching_selectable_documents.size
    @selected_selectable_documents = selected_selectable_documents(selectable_documents_all)
    @selected_selectable_document_count = @selected_selectable_documents.size
    @selectable_documents = candidate_view_selected? ? @selected_selectable_documents : @matching_selectable_documents
    @selectable_document_count = @selectable_documents.size
    @preview_document_limit = PREVIEW_DOCUMENT_LIMIT
    @selectable_documents_preview = preview_documents(@selectable_documents)
    @selectable_documents_truncated = @selectable_document_count > @selectable_documents_preview.size
    @scoped_link_params = scoped_link_params
    @plan = AiContextExportPlan.new(project: @project, viewer: current_user, scope: @scope).call
    @plan_included_items_preview = @plan.included_items.first(PREVIEW_DOCUMENT_LIMIT)
    @plan_excluded_items_preview = @plan.excluded_items.first(PREVIEW_DOCUMENT_LIMIT)
    @hash = AiContextHashExporter.new(project: @project, viewer: current_user, mode: @mode, scope: @scope).call

    respond_to do |format|
      format.html { record_ai_context_access_log!(:view) }
      format.json do
        record_ai_context_access_log!(:download)
        render json: @hash
      end
      format.md do
        record_ai_context_access_log!(:download)
        render plain: AiContextMarkdownExporter.new(project: @project, viewer: current_user, mode: @mode, scope: @scope).call,
          content_type: "text/markdown; charset=utf-8"
      end
    end
  end

  private

  SUPPORTED_MODES = AiContextHashExporter::MODES.index_by(&:to_s).freeze

  def set_project
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def requested_mode
    SUPPORTED_MODES[params.fetch(:mode, :compact).to_s]
  end

  def render_unsupported_mode
    respond_to do |format|
      format.html { render plain: "unsupported mode", status: :bad_request }
      format.json { render json: { error: "unsupported mode" }, status: :bad_request }
      format.md { render plain: "unsupported mode\n", status: :bad_request, content_type: "text/markdown; charset=utf-8" }
    end
  end

  def requested_document_ids
    Array(params[:document_ids]).filter_map do |value|
      id = Integer(value, exception: false)
      id if id&.positive?
    end.uniq
  end

  def requested_scope
    return nil if @requested_document_ids.empty?

    @project.documents.where(id: @requested_document_ids)
  end

  def scoped_document_count
    @scope&.count || 0
  end

  def requested_candidate_view
    return "selected" if params[:candidate_view].to_s == "selected" && @requested_document_ids.any?

    "all"
  end

  def candidate_view_selected?
    @candidate_view == "selected"
  end

  def selectable_documents
    Document.accessible_to(current_user)
      .where(project: @project)
      .includes(:project, :latest_version)
      .select { _1.visible_in_portal_for?(current_user) }
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def filtered_selectable_documents(documents)
    return documents if @document_query.blank?

    normalized_query = @document_query.downcase
    filtered = documents.select do |document|
      [document.title, document.slug].any? { _1.to_s.downcase.include?(normalized_query) }
    end
    selected = selected_selectable_documents(documents)

    (filtered + selected).uniq
  end

  def selected_selectable_documents(documents)
    documents.select { @requested_document_ids.include?(_1.id) }
  end

  def preview_documents(documents)
    visible_preview = documents.first(PREVIEW_DOCUMENT_LIMIT)
    return visible_preview if @requested_document_ids.empty? || candidate_view_selected?

    selected_documents = documents.select { @requested_document_ids.include?(_1.id) }
    (visible_preview + selected_documents).uniq
  end

  def scoped_link_params
    return {} if @requested_document_ids.empty?

    { document_ids: @requested_document_ids }
  end

  def normalized_document_query
    params[:document_q].to_s.strip.slice(0, DOCUMENT_QUERY_MAX_LENGTH)
  end

  def document_query_max_length
    DOCUMENT_QUERY_MAX_LENGTH
  end

  def record_ai_context_access_log!(action_type)
    AccessLog.create!(
      user: current_user,
      company: current_user.company,
      project: @project,
      action_type:,
      target_type: "ai_context",
      target_name: ai_context_access_log_target_name,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("AI context AccessLog skipped: #{e.class}: #{e.message}")
  end

  def ai_context_access_log_target_name
    [
      "mode=#{@mode}",
      "scope=#{@requested_document_ids.empty? ? "all" : "selected"}",
      "selected_count=#{@requested_document_ids.size}",
      "scoped_count=#{@scoped_document_count}",
      "exported_count=#{ai_context_exported_document_count}"
    ].join(";")
  end

  def ai_context_exported_document_count
    @hash.dig(:summary, :document_count) || @hash.dig("summary", "document_count") || 0
  end
end
