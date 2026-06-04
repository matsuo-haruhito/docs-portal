class Admin::AccessLogsController < Admin::BaseController
  AI_CONTEXT_MODE_FILTERS = %w[compact full].freeze
  AI_CONTEXT_SCOPE_FILTERS = %w[all selected].freeze
  ACCESS_LOGS_PER_PAGE = 200
  ACCESS_LOGS_MAX_PAGE = 50

  before_action :require_admin_only!

  def index
    @filters = filter_params
    @page = page_param
    @projects = Project.order(:code)
    @companies = Company.order(:domain)
    @users = User.order(:email_address)
    @access_logs = paginated_access_logs
    @has_previous_page = @page > 1
    @has_next_page = @access_logs.size > ACCESS_LOGS_PER_PAGE
    @access_logs = @access_logs.first(ACCESS_LOGS_PER_PAGE)
    @reached_display_limit = @access_logs.size >= ACCESS_LOGS_PER_PAGE
    @pagination_params = pagination_params
  end

  private

  def paginated_access_logs
    filtered_access_logs
      .includes(:user, :company, :project, :document, :document_version)
      .order(accessed_at: :desc, id: :desc)
      .offset((@page - 1) * ACCESS_LOGS_PER_PAGE)
      .limit(ACCESS_LOGS_PER_PAGE + 1)
  end

  def filtered_access_logs
    scope = AccessLog.all
    scope = scope.where(action_type: @filters[:action_type]) if @filters[:action_type].present? && AccessLog.action_types.key?(@filters[:action_type])
    scope = scope.where(target_type: @filters[:target_type]) if @filters[:target_type].present?
    scope = apply_ai_context_filters(scope)
    scope = scope.where(project_id: @filters[:project_id]) if @filters[:project_id].present?
    scope = scope.where(company_id: @filters[:company_id]) if @filters[:company_id].present?
    scope = scope.where(user_id: @filters[:user_id]) if @filters[:user_id].present?
    scope = scope.where(document_id: document_scope.select(:id)) if @filters[:document_q].present?
    scope = apply_target_or_ip_filter(scope)
    scope = apply_accessed_at_filters(scope)
    scope
  end

  def apply_ai_context_filters(scope)
    return scope unless @filters[:target_type].to_s == "ai_context"

    if @filters[:ai_context_mode].present?
      mode = ActiveRecord::Base.sanitize_sql_like(@filters[:ai_context_mode].to_s)
      scope = scope.where("target_name LIKE ?", "%mode=#{mode};%")
    end

    if @filters[:ai_context_scope].present?
      export_scope = ActiveRecord::Base.sanitize_sql_like(@filters[:ai_context_scope].to_s)
      scope = scope.where("target_name LIKE ?", "%scope=#{export_scope};%")
    end

    scope
  end

  def apply_target_or_ip_filter(scope)
    value = @filters[:q].to_s.strip
    return scope if value.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
    scope.where("(target_name LIKE :query OR ip_address LIKE :query)", query:)
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
    permitted = params.permit(:action_type, :target_type, :project_id, :company_id, :user_id, :q, :document_q, :from, :to, :ai_context_mode, :ai_context_scope)
    permitted[:target_type] = nil if unknown_target_type_filter?(permitted[:target_type])
    permitted[:ai_context_mode] = nil if unknown_ai_context_mode_filter?(permitted[:ai_context_mode])
    permitted[:ai_context_scope] = nil if unknown_ai_context_scope_filter?(permitted[:ai_context_scope])

    if permitted[:target_type].to_s != "ai_context"
      permitted[:ai_context_mode] = nil
      permitted[:ai_context_scope] = nil
    end

    permitted
  end

  def page_param
    page = params[:page].to_i
    page.between?(1, ACCESS_LOGS_MAX_PAGE) ? page : 1
  end

  def pagination_params
    @filters.to_h.each_with_object({}) do |(key, value), params_hash|
      params_hash[key] = value if value.present?
    end
  end

  def unknown_target_type_filter?(target_type)
    target_type.present? && AccessLog::TARGET_TYPE_FILTERS.exclude?(target_type)
  end

  def unknown_ai_context_mode_filter?(mode)
    mode.present? && AI_CONTEXT_MODE_FILTERS.exclude?(mode)
  end

  def unknown_ai_context_scope_filter?(scope)
    scope.present? && AI_CONTEXT_SCOPE_FILTERS.exclude?(scope)
  end
end