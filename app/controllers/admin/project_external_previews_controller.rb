class Admin::ProjectExternalPreviewsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project
  before_action :load_preview_options

  def show
    @resolved_preview_users = resolve_preview_users
    @preview_requested = @selected_user.present? || @selected_company.present?
    @preview_hashes = @resolved_preview_users.map { ExternalVisibilityPreviewHash.new(project: @project, viewer: _1).call }
    record_preview_access_log! if @preview_requested
  end

  private

  def set_project
    @project = Project.find_by!(code: params[:id])
  end

  def load_preview_options
    @preview_users = external_viewer_scope.includes(:company).order(:email_address)
    @preview_companies = Company.joins(:users).merge(external_viewer_scope).distinct.order(:name)
    @selected_user = @preview_users.find { _1.id == preview_params[:user_id].to_i } if preview_params[:user_id].present?
    @selected_company = @preview_companies.find { _1.id == preview_params[:company_id].to_i } if preview_params[:company_id].present?
  end

  def resolve_preview_users
    if @selected_user.present?
      [@selected_user]
    elsif @selected_company.present?
      @preview_users.select { _1.company_id == @selected_company.id }
    else
      []
    end
  end

  def preview_requested?
    @selected_user.present? || @selected_company.present?
  end

  def preview_target_name
    if @selected_user.present?
      "user:#{@selected_user.email_address}"
    elsif @selected_company.present?
      "company:#{@selected_company.name} viewers=#{@resolved_preview_users.size}"
    else
      "external_preview"
    end
  end

  def record_preview_access_log!
    AccessLog.create!(
      user: current_user,
      company: @selected_user&.company || @selected_company,
      project: @project,
      action_type: :view,
      target_type: "external_preview",
      target_name: preview_target_name,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("External preview AccessLog skipped: #{e.class}: #{e.message}")
  end

  def external_viewer_scope
    User.active_only.where(user_type: User.user_types.values_at("external", "company_master_admin"))
  end

  def preview_params
    @preview_params ||= params.permit(:user_id, :company_id)
  end
end
