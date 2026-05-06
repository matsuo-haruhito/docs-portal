class ProjectAiContextsController < BaseController
  before_action :set_project

  def show
    @mode = requested_mode
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

  def set_project
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def requested_mode
    params.fetch(:mode, :compact).to_sym
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
