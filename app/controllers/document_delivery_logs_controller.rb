require "csv"

class DocumentDeliveryLogsController < BaseController
  before_action :set_context, only: %i[new create]
  before_action :set_delivery_log, only: %i[show update]

  DELIVERY_LOG_DISPLAY_LIMIT = 50
  DELIVERY_LOG_QUERY_MAX_LENGTH = 100
  DELIVERY_LOG_CSV_PREVIEW_MAX_LENGTH = 120
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"
  DELIVERY_LOG_CSV_AUTHORIZATION_VALUE_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^,\s;]+/i
  DELIVERY_LOG_CSV_AUTH_SCHEME_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^,\s;]+/i
  DELIVERY_LOG_CSV_SECRET_LIKE_PATTERN = /\b(?:token|secret|password|api[_-]?key|access[_-]?token)\s*([=:])\s*[^\s,;]+/i
  FAILURE_ALERT_HANDOFF_PRESENT_NOTE = "read-only handoff payloadです。通知送信、ack、自動 retry、送付状態変更は行いません。".freeze
  FAILURE_ALERT_HANDOFF_EMPTY_NOTE = "current 条件で handoff 対象なし。これは正常保証、外部監視 green、通知正常を意味しません。".freeze

  STATUS_FILTER_LABELS = {
    "draft" => "下書き",
    "sent" => "送付済み",
    "failed" => "失敗"
  }.freeze

  DELIVERY_LOG_SEARCH_COLUMNS = %w[
    projects.name
    projects.code
    document_delivery_logs.to_addresses
    document_delivery_logs.cc_addresses
    document_delivery_logs.bcc_addresses
    document_delivery_logs.subject
    document_delivery_logs.error_message
  ].freeze

  DELIVERY_LOG_CSV_HEADERS = [
    "作成日時",
    "送信日時",
    "案件コード",
    "案件名",
    "対象種別",
    "対象名",
    "To",
    "CC",
    "BCC",
    "方式",
    "状態",
    "失敗理由"
  ].freeze

  def index
    base_scope = current_user.internal? ? DocumentDeliveryLog.all : DocumentDeliveryLog.where(sender: current_user)

    @status_filter = normalized_status_filter
    @delivery_type_filter = normalized_delivery_type_filter
    @query = normalized_query
    @created_from_filter = normalized_delivery_log_date_filter(:created_from)
    @created_to_filter = normalized_delivery_log_date_filter(:created_to)
    @sent_from_filter = normalized_delivery_log_date_filter(:sent_from)
    @sent_to_filter = normalized_delivery_log_date_filter(:sent_to)
    @created_from_date = parse_delivery_log_date_filter(@created_from_filter)
    @created_to_date = parse_delivery_log_date_filter(@created_to_filter)
    @sent_from_date = parse_delivery_log_date_filter(@sent_from_filter)
    @sent_to_date = parse_delivery_log_date_filter(@sent_to_filter)
    @created_date_filter_invalid = (@created_from_filter.present? && @created_from_date.blank?) || (@created_to_filter.present? && @created_to_date.blank?)
    @sent_date_filter_invalid = (@sent_from_filter.present? && @sent_from_date.blank?) || (@sent_to_filter.present? && @sent_to_date.blank?)

    searchable_scope = filter_by_query(base_scope)
    date_filtered_scope = filter_by_sent_at(filter_by_created_at(searchable_scope))
    @status_summary_counts = STATUS_FILTER_LABELS.keys.index_with { |status| date_filtered_scope.public_send(status).count }

    status_filter_scope = @delivery_type_filter.present? ? date_filtered_scope.public_send(@delivery_type_filter) : date_filtered_scope
    @status_filter_counts = STATUS_FILTER_LABELS.keys.index_with { |status| status_filter_scope.public_send(status).count }

    delivery_type_filter_scope = @status_filter.present? ? date_filtered_scope.public_send(@status_filter) : date_filtered_scope
    @delivery_type_counts = DocumentDeliveryLog.delivery_types.keys.index_with do |delivery_type|
      delivery_type_filter_scope.public_send(delivery_type).count
    end

    scoped_scope = date_filtered_scope
    scoped_scope = scoped_scope.public_send(@status_filter) if @status_filter.present?
    scoped_scope = scoped_scope.public_send(@delivery_type_filter) if @delivery_type_filter.present?
    @delivery_logs_total_count = scoped_scope.count
    @delivery_logs_limit = DELIVERY_LOG_DISPLAY_LIMIT
    @delivery_logs_total_pages = [(@delivery_logs_total_count.to_f / @delivery_logs_limit).ceil, 1].max
    @delivery_logs_page = normalized_delivery_logs_page(@delivery_logs_total_pages)
    @delivery_logs_offset = (@delivery_logs_page - 1) * @delivery_logs_limit
    @delivery_logs = scoped_scope
      .includes(:project, :document, :document_set, :sender)
      .recent_first
      .offset(@delivery_logs_offset)
      .limit(@delivery_logs_limit)

    respond_to do |format|
      format.html
      format.csv do
        export_logs = scoped_scope
          .includes(:project, :document, :document_set)
          .recent_first
          .limit(DELIVERY_LOG_DISPLAY_LIMIT)

        send_data document_delivery_logs_csv(export_logs),
          filename: "document-delivery-logs-#{Time.zone.today.iso8601}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
  end

  def failure_alert_handoff
    raise ApplicationError::Forbidden unless current_user.internal?

    entries = DocumentDeliveryLogs::FailureAlertHandoff.new.call.map(&:to_h)

    render json: {
      generated_at: Time.current.iso8601,
      count: entries.size,
      note: entries.any? ? FAILURE_ALERT_HANDOFF_PRESENT_NOTE : FAILURE_ALERT_HANDOFF_EMPTY_NOTE,
      runbook_path: DocumentDeliveryLogs::FailureAlertHandoff::RUNBOOK_PATH,
      entries: entries
    }
  end

  def show
    raise ApplicationError::Forbidden unless visible_log?(@delivery_log)

    @return_to_path = safe_return_to_path(document_delivery_logs_path)
    @mailto_url = build_mailto_url(@delivery_log)
  end

  def new
    @delivery_log = build_delivery_log
  end

  def create
    @delivery_log = build_delivery_log(delivery_log_params)

    if read_only_maintenance_mode?
      redirect_to delivery_log_create_maintenance_redirect_path, alert: maintenance_delivery_log_message
      return
    end

    if @delivery_log.save
      redirect_to document_delivery_log_path(@delivery_log), notice: "送付下書きを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    raise ApplicationError::Forbidden unless visible_log?(@delivery_log)

    case params[:decision]
    when "mark_sent"
      require_draft_delivery_log!
      return if stop_delivery_log_update_for_maintenance?

      @delivery_log.update!(status: :sent, sent_at: Time.current, error_message: nil)
      redirect_to delivery_log_redirect_path, notice: "送付済みにしました。"
    when "mark_failed"
      require_draft_delivery_log!
      return if stop_delivery_log_update_for_maintenance?

      @delivery_log.update!(status: :failed, error_message: params[:error_message].to_s.presence || "manual mark")
      redirect_to delivery_log_redirect_path, notice: "送付失敗として記録しました。"
    else
      raise ApplicationError::BadRequest, "unsupported decision"
    end
  end

  private

  def set_context
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)

    @document =
      if params[:document_slug].present? || params[:slug].present?
        @project.documents.find_by!(slug: params[:document_slug] || params[:slug]).tap { require_document_access!(_1) }
      end

    @document_set =
      if params[:document_set_public_id].present? || params[:public_id].present?
        @project.document_sets.find_by!(public_id: params[:document_set_public_id] || params[:public_id]).tap do |set|
          raise ApplicationError::Forbidden unless set.viewable_by?(current_user)
        end
      end
  end

  def set_delivery_log
    @delivery_log = DocumentDeliveryLog.includes(:project, :document, :document_set, :sender).find_by!(public_id: params[:public_id])
  end

  def build_delivery_log(extra_attributes = {})
    DocumentDeliveryLogBuilder.new(
      sender: current_user,
      project: @project,
      document: @document,
      document_set: @document_set,
      attributes: default_attributes.merge(extra_attributes)
    ).build
  end

  def default_attributes
    {
      subject: default_subject,
      body: default_body,
      delivery_type: :portal_link
    }
  end

  def default_subject
    target_label = @document&.title || @document_set&.name || @project.name
    "[Document Portal] #{target_label}"
  end

  def default_body
    <<~TEXT.strip
      以下の資料をご確認ください。

      #{target_url}
    TEXT
  end

  def target_url
    if @document.present?
      project_document_url(@project, @document.slug)
    elsif @document_set.present?
      project_document_set_url(@project, @document_set)
    else
      project_url(@project)
    end
  end

  def delivery_log_params
    params.require(:document_delivery_log).permit(:to_addresses, :cc_addresses, :bcc_addresses, :subject, :body)
  end

  def visible_log?(log)
    current_user.internal? || log.sender == current_user
  end

  def require_draft_delivery_log!
    raise ApplicationError::BadRequest, "manual update is allowed only for draft delivery logs" unless @delivery_log.draft?
  end

  def stop_delivery_log_update_for_maintenance?
    return false unless read_only_maintenance_mode?

    redirect_to delivery_log_redirect_path, alert: maintenance_delivery_log_message
    true
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_delivery_log_message
    "メンテナンス中のため外部送付履歴の下書き作成・手動状態更新は停止しています。閲覧は継続できます。"
  end

  def delivery_log_create_maintenance_redirect_path
    return project_document_path(@project, @document.slug) if @document.present?
    return project_document_set_path(@project, @document_set) if @document_set.present?

    project_path(@project)
  end

  def build_mailto_url(log)
    query = {
      cc: log.cc_addresses,
      bcc: log.bcc_addresses,
      subject: log.subject,
      body: log.body
    }.compact.to_query
    "mailto:#{ERB::Util.url_encode(log.recipients.join(","))}?#{query}"
  end

  def document_delivery_logs_csv(logs)
    CSV.generate(headers: true) do |csv|
      csv << DELIVERY_LOG_CSV_HEADERS
      logs.each do |log|
        csv << [
          csv_time(log.created_at),
          csv_time(log.sent_at),
          log.project.code,
          log.project.name,
          csv_target_type(log),
          csv_target_name(log),
          csv_preview(log.to_addresses),
          csv_preview(log.cc_addresses),
          csv_preview(log.bcc_addresses),
          localized_delivery_type(log.delivery_type),
          localized_status(log.status),
          log.failed? ? csv_preview(log.error_message, limit: 80) : nil
        ]
      end
    end
  end

  def csv_time(value)
    I18n.l(value) if value.present?
  end

  def csv_target_type(log)
    return "文書" if log.document.present?
    return "文書セット" if log.document_set.present?

    "案件"
  end

  def csv_target_name(log)
    log.document&.title || log.document_set&.name || log.project.name
  end

  def localized_delivery_type(delivery_type)
    I18n.t("labels.document_delivery_logs.delivery_type.#{delivery_type}", default: delivery_type.to_s)
  end

  def localized_status(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def csv_preview(value, limit: DELIVERY_LOG_CSV_PREVIEW_MAX_LENGTH)
    text = mask_csv_preview(value.to_s.squish)
    return if text.blank?
    return text if text.length <= limit

    "#{text.first(limit)}..."
  end

  def mask_csv_preview(text)
    text
      .gsub(DELIVERY_LOG_CSV_AUTHORIZATION_VALUE_PATTERN) { "#{$1}: #{$2} [FILTERED]" }
      .gsub(DELIVERY_LOG_CSV_AUTH_SCHEME_VALUE_PATTERN) { "#{$1} [FILTERED]" }
      .gsub(DELIVERY_LOG_CSV_SECRET_LIKE_PATTERN) { |match| match.sub(/#{Regexp.escape(Regexp.last_match(1))}[^\s,;]+\z/, "#{Regexp.last_match(1)}[FILTERED]") }
  end

  def normalized_status_filter
    params[:status].presence_in(DocumentDeliveryLog.statuses.keys)
  end

  def normalized_delivery_type_filter
    params[:delivery_type].presence_in(DocumentDeliveryLog.delivery_types.keys)
  end

  def normalized_query
    params[:q].to_s.strip.presence&.slice(0, DELIVERY_LOG_QUERY_MAX_LENGTH)
  end

  def normalized_delivery_log_date_filter(param_name)
    params[param_name].to_s.strip.presence
  end

  def normalized_delivery_logs_page(total_pages)
    page = Integer(params[:page].presence || 1, exception: false)
    return 1 if page.blank? || page < 1

    page.clamp(1, total_pages)
  end

  def parse_delivery_log_date_filter(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def filter_by_query(scope)
    return scope if @query.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
    conditions = DELIVERY_LOG_SEARCH_COLUMNS.map { |column| "LOWER(#{column}) LIKE :query" }.join(" OR ")
    scope.joins(:project).where(conditions, query:)
  end

  def filter_by_created_at(scope)
    scoped = scope
    scoped = scoped.where("document_delivery_logs.created_at >= ?", @created_from_date.beginning_of_day) if @created_from_date.present?
    scoped = scoped.where("document_delivery_logs.created_at <= ?", @created_to_date.end_of_day) if @created_to_date.present?
    scoped
  end

  def filter_by_sent_at(scope)
    scoped = scope
    scoped = scoped.where("document_delivery_logs.sent_at >= ?", @sent_from_date.beginning_of_day) if @sent_from_date.present?
    scoped = scoped.where("document_delivery_logs.sent_at <= ?", @sent_to_date.end_of_day) if @sent_to_date.present?
    scoped
  end

  def delivery_log_redirect_path
    return document_delivery_log_path(@delivery_log) unless params.key?(:return_to)

    document_delivery_log_path(@delivery_log, return_to: safe_return_to_path(document_delivery_logs_path))
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return fallback if return_to.blank?
    return fallback unless return_to.start_with?("/")
    return fallback if return_to.start_with?("//")
    return fallback if return_to.match?(/[[:cntrl:]]/)

    return_to
  end
end
