require "csv"

class Admin::AccessLogsController < Admin::BaseController
  AI_CONTEXT_MODE_FILTERS = %w[compact full].freeze
  AI_CONTEXT_SCOPE_FILTERS = %w[all selected].freeze
  ACCESS_LOGS_PER_PAGE = 200
  ACCESS_LOGS_MAX_PAGE = 50
  ACCESS_LOG_QUERY_MAX_LENGTH = 100
  FILTER_CANDIDATE_LIMIT = 50
  CSV_HEADERS = [
    "日時",
    "操作",
    "対象種別",
    "対象名",
    "AI context mode",
    "AI context scope",
    "AI context selected_count",
    "AI context exported_count",
    "ユーザー名",
    "ユーザーEmail",
    "会社",
    "案件コード",
    "案件名",
    "文書名",
    "文書URL識別子",
    "版",
    "IPアドレス"
  ].freeze

  before_action :require_admin_only!

  def index
    @filters = filter_params
    @ignored_date_filters = []

    respond_to do |format|
      format.html do
        @page = page_param
        @projects = access_log_filter_candidates(Project.order(:code), @filters[:project_id])
        @companies = access_log_filter_candidates(Company.order(:domain), @filters[:company_id])
        @users = access_log_filter_candidates(User.order(:email_address), @filters[:user_id])
        @access_logs = paginated_access_logs
        @has_previous_page = @page > 1
        @has_next_page = @access_logs.size > ACCESS_LOGS_PER_PAGE
        @access_logs = @access_logs.first(ACCESS_LOGS_PER_PAGE)
        @reached_display_limit = @access_logs.size >= ACCESS_LOGS_PER_PAGE
        @pagination_params = pagination_params
      end
      format.csv do
        send_data access_logs_csv,
                  filename: access_logs_csv_filename,
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  private

  def paginated_access_logs
    filtered_access_logs
      .includes(:user, :company, :project, :document, :document_version)
      .order(accessed_at: :desc, id: :desc)
      .offset((@page - 1) * ACCESS_LOGS_PER_PAGE)
      .limit(ACCESS_LOGS_PER_PAGE + 1)
  end

  def csv_access_logs
    filtered_access_logs
      .includes(:user, :company, :project, :document, :document_version)
      .order(accessed_at: :desc, id: :desc)
      .limit(ACCESS_LOGS_PER_PAGE)
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
    value = @filters[:q].to_s
    return scope if value.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
    scope.where("(target_name LIKE :query OR ip_address LIKE :query)", query:)
  end

  def apply_accessed_at_filters(scope)
    from_date = parse_filter_date(@filters[:from], :from)
    to_date = parse_filter_date(@filters[:to], :to)

    scope = scope.where("accessed_at >= ?", from_date.beginning_of_day) if from_date
    scope = scope.where("accessed_at <= ?", to_date.end_of_day) if to_date
    scope
  end

  def parse_filter_date(value, filter_name = nil)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    @ignored_date_filters << filter_name if filter_name && !@ignored_date_filters.include?(filter_name)
    nil
  end

  def document_scope
    query = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:document_q].to_s)}%"
    Document.where("title LIKE :query OR slug LIKE :query", query:)
  end

  def access_logs_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      csv_access_logs.each do |log|
        csv << access_logs_csv_row(log)
      end
    end
  end

  def access_logs_csv_row(log)
    ai_context_values = access_log_csv_ai_context_values(log)

    [
      log.accessed_at.strftime("%Y-%m-%d %H:%M:%S"),
      log.action_type,
      log.target_type,
      log.target_name,
      ai_context_values.fetch("mode", ""),
      ai_context_values.fetch("scope", ""),
      ai_context_values.fetch("selected_count", ""),
      ai_context_values.fetch("exported_count", ""),
      log.user&.display_name,
      log.user&.email_address,
      log.company&.display_name,
      log.project&.code,
      log.project&.name,
      log.document&.title,
      log.document&.slug,
      log.document_version&.version_label,
      log.ip_address
    ]
  end

  def access_log_csv_ai_context_values(log)
    return {} unless log.target_type.to_s == "ai_context"

    raw_target_name = log.target_name.to_s.strip
    return {} if raw_target_name.blank?

    pairs = raw_target_name.split(";").each_with_object({}) do |part, values|
      key, value = part.split("=", 2).map { _1.to_s.strip }
      return {} if key.blank? || value.blank?

      values[key] = value
    end

    return {} unless %w[mode scope selected_count exported_count].all? { pairs[_1].present? }
    return {} unless pairs["selected_count"].match?(/\A\d+\z/) && pairs["exported_count"].match?(/\A\d+\z/)

    pairs.slice("mode", "scope", "selected_count", "exported_count")
  end

  def access_logs_csv_filename
    "access-logs-#{Date.current.iso8601}.csv"
  end

  def filter_params
    permitted = params.permit(:action_type, :target_type, :project_id, :company_id, :user_id, :q, :document_q, :from, :to, :ai_context_mode, :ai_context_scope)
    permitted[:target_type] = nil if unknown_target_type_filter?(permitted[:target_type])
    permitted[:ai_context_mode] = nil if unknown_ai_context_mode_filter?(permitted[:ai_context_mode])
    permitted[:ai_context_scope] = nil if unknown_ai_context_scope_filter?(permitted[:ai_context_scope])
    permitted[:q] = normalized_access_log_query(permitted[:q]).presence
    permitted[:document_q] = normalized_access_log_query(permitted[:document_q]).presence

    if permitted[:target_type].to_s != "ai_context"
      permitted[:ai_context_mode] = nil
      permitted[:ai_context_scope] = nil
    end

    permitted
  end

  def normalized_access_log_query(value)
    value.to_s.strip.first(ACCESS_LOG_QUERY_MAX_LENGTH)
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

  def access_log_filter_candidates(scope, selected_id)
    records = scope.limit(FILTER_CANDIDATE_LIMIT).to_a
    return records if selected_id.blank? || records.any? { _1.id.to_s == selected_id.to_s }

    selected_record = scope.unscope(:order).find_by(id: selected_id)
    selected_record ? records + [selected_record] : records
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
