class ProjectAiContextsController < BaseController
  before_action :set_project

  def show
    @mode = requested_mode
    return render_unsupported_mode unless @mode

    @scope = requested_scope
    @plan = AiContextExportPlan.new(project: @project, viewer: current_user, scope: @scope).call
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

  def requested_scope
    ids = Array(params[:document_ids]).map(&:to_i).uniq
    return nil if ids.empty?

    @project.documents.where(id: ids)
  end

  def record_ai_context_access_log!(action_type)
    AccessLog.create!(
      user: current_user,
      company: current_user.company,
      project: @project,
      action_type:,
      target_type: "ai_context",
      target_name: "mode=#{@mode}",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("AI context AccessLog skipped: #{e.class}: #{e.message}")
  end
end
