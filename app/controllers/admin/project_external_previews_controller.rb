class Admin::ProjectExternalPreviewsController < Admin::BaseController
  PREVIEW_SEARCH_LIMIT = 20
  PREVIEW_SEARCH_QUERY_MAX_LENGTH = 100

  before_action :require_admin_only!
  before_action :set_project
  before_action :load_preview_options, only: :show

  def show
    @resolved_preview_users = resolve_preview_users
    @preview_requested = @selected_user.present? || @selected_company.present?
    @preview_hashes = @resolved_preview_users.map { ExternalVisibilityPreviewHash.new(project: @project, viewer: _1).call }
    record_preview_access_log! if @preview_requested
  end

  def user_search
    render json: { options: external_preview_user_options(searchable_preview_users) }
  end

  def selected_user
    user = selected_external_viewer(params[:id])

    render json: { option: user ? external_preview_user_option(user) : nil }
  end

  def company_search
    render json: { options: external_preview_company_options(searchable_preview_companies) }
  end

  def selected_company
    company = selected_external_company(params[:id])

    render json: { option: company ? external_preview_company_option(company) : nil }
  end

  private

  def set_project
    @project = Project.find_by!(code: project_code_param)
  end

  def project_code_param
    params[:code] || params[:id]
  end

  def load_preview_options
    @selected_user = selected_external_viewer(preview_params[:user_id])
    @selected_company = selected_external_company(preview_params[:company_id])
  end

  def resolve_preview_users
    if @selected_user.present?
      [@selected_user]
    elsif @selected_company.present?
      external_viewer_scope
        .where(company_id: @selected_company.id)
        .includes(:company)
        .order(:email_address)
        .to_a
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

  def external_viewer_company_scope
    Company.joins(:users).merge(external_viewer_scope).distinct
  end

  def searchable_preview_users
    scope = external_viewer_scope.left_joins(:company).includes(:company).order(:email_address, :id)
    query = normalized_preview_search_query(params[:q])
    return scope.limit(PREVIEW_SEARCH_LIMIT) if query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(users.name) LIKE :pattern OR LOWER(users.email_address) LIKE :pattern OR LOWER(companies.name) LIKE :pattern OR LOWER(companies.domain) LIKE :pattern",
      pattern:
    ).limit(PREVIEW_SEARCH_LIMIT)
  end

  def searchable_preview_companies
    scope = external_viewer_company_scope.order(:name, :domain, :id)
    query = normalized_preview_search_query(params[:q])
    return scope.limit(PREVIEW_SEARCH_LIMIT) if query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(companies.name) LIKE :pattern OR LOWER(companies.domain) LIKE :pattern",
      pattern:
    ).limit(PREVIEW_SEARCH_LIMIT)
  end

  def selected_external_viewer(user_id)
    return if user_id.blank?

    external_viewer_scope.includes(:company).find_by(id: user_id)
  end

  def selected_external_company(company_id)
    return if company_id.blank?

    external_viewer_company_scope.find_by(id: company_id)
  end

  def normalized_preview_search_query(value)
    value.to_s.strip.first(PREVIEW_SEARCH_QUERY_MAX_LENGTH)
  end

  def external_preview_user_options(users)
    users.map { external_preview_user_option(_1) }
  end

  def external_preview_user_option(user)
    { value: user.id, text: helpers.external_preview_user_label(user) }
  end

  def external_preview_company_options(companies)
    companies.map { external_preview_company_option(_1) }
  end

  def external_preview_company_option(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?

    { value: company.id, text: label }
  end

  def preview_params
    @preview_params ||= params.permit(:user_id, :company_id)
  end
end