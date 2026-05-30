class Admin::AccessLogsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @filters = filter_params
    @projects = Project.order(:code)
    @companies = Company.order(:domain)
    @users = User.order(:email_address)
    @access_logs = filtered_access_logs
      .includes(:user, :company, :project, :document, :document_version)
      .order(accessed_at: :desc, id: :desc)
      .limit(200)
  end

  private

  def filtered_access_logs
    scope = AccessLog.all
    scope = scope.where(action_type: @filters[:action_type]) if @filters[:action_type].present? && AccessLog.action_types.key?(@filters[:action_type])
    scope = scope.where(target_type: @filters[:target_type]) if @filters[:target_type].present?
    scope = scope.where(project_id: @filters[:project_id]) if @filters[:project_id].present?
    scope = scope.where(company_id: @filters[:company_id]) if @filters[:company_id].present?
    scope = scope.where(user_id: @filters[:user_id]) if @filters[:user_id].present?
    scope = scope.where(document_id: document_scope.select(:id)) if @filters[:document_q].present?
    scope = apply_accessed_at_filters(scope)
    scope
  end

  def apply_accessed_at_filters(scope)
    from_date = parse_filter_date(@filters[:from])
    to_date = parse_filter_date(@filters[:to])

    scope = scope.where("accessed_at >= ?", from_date.beginning_of_day) if from_date
    scope = scope.where("accessed_at <= ?", to_date.end_of_day) if to_date
    scope
  end

  def parse_filter_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def document_scope
    query = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:document_q].to_s.strip)}%"
    Document.where("title LIKE :query OR slug LIKE :query", query:)
  end

  def filter_params
    params.permit(:action_type, :target_type, :project_id, :company_id, :user_id, :document_q, :from, :to)
  end
end
