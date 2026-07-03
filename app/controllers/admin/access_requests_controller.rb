class Admin::AccessRequestsController < Admin::BaseController
  before_action :require_admin_only!

  ACCESS_REQUEST_QUERY_MAX_LENGTH = AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH
  READ_ONLY_MAINTENANCE_ENV = AccessRequestsController::READ_ONLY_MAINTENANCE_ENV
  PENDING_HANDOFF_LIMIT = 50
  REASON_PREVIEW_LENGTH = 80

  REJECTION_REASON_PRESETS = {
    "permission_shortage" => "権限不足",
    "wrong_target" => "対象誤り",
    "insufficient_information" => "情報不足",
    "approval_mismatch" => "承認条件不一致"
  }.freeze

  helper_method :admin_access_request_query_max_length

  def index
    @filters = filter_params
    scope = filtered_access_request_scope
    @access_requests_filtered_count = scope.unscope(:order).count
    @access_requests, @access_requests_pagination = paginate_admin_list(scope, @access_requests_filtered_count)
    @access_request_page_params = access_request_page_params
    @status_counts = access_request_status_counts(scope)
  end

  def show
    @access_request = AccessRequest.includes(:requester, :approver, :requestable).find_by!(public_id: params[:public_id])
    @request_hash = AccessRequestHash.new(@access_request).call
    @requestable = @request_hash[:requestable]
    @return_to = safe_return_to_path || admin_access_requests_path
  end

  def pending_handoff
    @filters = filter_params
    pending_scope = filtered_access_request_scope.pending
    total_count = pending_scope.unscope(:order).count
    candidates = pending_scope.limit(PENDING_HANDOFF_LIMIT).map { |access_request| pending_handoff_candidate(access_request) }

    render json: {
      current_filter: @filters.compact,
      status: "pending",
      total_count:,
      limit: PENDING_HANDOFF_LIMIT,
      truncated: total_count > PENDING_HANDOFF_LIMIT,
      note: pending_handoff_note(total_count),
      candidates:
    }
  end

  def update
    access_request = AccessRequest.find_by!(public_id: params[:public_id])
    if read_only_maintenance_mode?
      redirect_to access_request_redirect_path, alert: access_request_maintenance_message
      return
    end

    resolver = AccessRequestResolver.new(access_request:, approver: current_user)

    case params[:decision]
    when "approve"
      resolver.approve!
      notice = "アクセス申請を承認しました。"
    when "reject"
      resolver.reject!(reason: rejection_reason_param)
      notice = "アクセス申請を却下しました。"
    else
      raise ApplicationError::BadRequest, "unsupported decision"
    end

    redirect_to access_request_redirect_path, notice:
  end

  private

  def filtered_access_request_scope
    scope = AccessRequest.recent_first.includes(:requester, :approver, :requestable)
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope = scope.where(requested_access_level: @filters[:requested_access_level]) if @filters[:requested_access_level].present?
    scope = scope.where(requestable_type: @filters[:requestable_type]) if @filters[:requestable_type].present?
    return scope if @filters[:q].blank?

    scope.where(
      access_request_search_condition,
      query: access_request_query_pattern(@filters[:q])
    )
  end

  def access_request_query_pattern(query)
    "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
  end

  def access_request_search_condition
    <<~SQL.squish
      LOWER(access_requests.public_id) LIKE :query
      OR LOWER(access_requests.reason) LIKE :query
      OR EXISTS (
        SELECT 1
        FROM users requesters
        WHERE requesters.id = access_requests.requester_id
          AND (
            LOWER(requesters.name) LIKE :query
            OR LOWER(requesters.email_address) LIKE :query
          )
      )
      OR (
        access_requests.requestable_type = 'Project'
        AND EXISTS (
          SELECT 1
          FROM projects
          WHERE projects.id = access_requests.requestable_id
            AND (
              LOWER(projects.public_id) LIKE :query
              OR LOWER(projects.code) LIKE :query
              OR LOWER(projects.name) LIKE :query
            )
        )
      )
      OR (
        access_requests.requestable_type = 'Document'
        AND EXISTS (
          SELECT 1
          FROM documents
          LEFT JOIN projects document_projects ON document_projects.id = documents.project_id
          WHERE documents.id = access_requests.requestable_id
            AND (
              LOWER(documents.public_id) LIKE :query
              OR LOWER(documents.slug) LIKE :query
              OR LOWER(documents.title) LIKE :query
              OR LOWER(document_projects.code) LIKE :query
              OR LOWER(document_projects.name) LIKE :query
            )
        )
      )
      OR (
        access_requests.requestable_type = 'DocumentFile'
        AND EXISTS (
          SELECT 1
          FROM document_files
          LEFT JOIN document_versions ON document_versions.id = document_files.document_version_id
          LEFT JOIN documents file_documents ON file_documents.id = document_versions.document_id
          LEFT JOIN projects file_projects ON file_projects.id = file_documents.project_id
          WHERE document_files.id = access_requests.requestable_id
            AND (
              LOWER(document_files.public_id) LIKE :query
              OR LOWER(document_files.file_name) LIKE :query
              OR LOWER(document_files.search_text) LIKE :query
              OR LOWER(file_documents.title) LIKE :query
              OR LOWER(file_documents.slug) LIKE :query
              OR LOWER(file_projects.code) LIKE :query
              OR LOWER(file_projects.name) LIKE :query
            )
        )
      )
    SQL
  end

  def access_request_status_counts(scope)
    counts = scope.unscope(:order).group(:status).count
    AccessRequest.statuses.keys.to_h do |status|
      [status, counts[status].to_i]
    end
  end

  def pending_handoff_candidate(access_request)
    request_hash = AccessRequestHash.new(access_request).call
    requestable = request_hash[:requestable]

    {
      public_id: access_request.public_id,
      requester: requester_preview(access_request.requester),
      requestable_type: access_request.requestable_type,
      requestable_label: primary_target_label(requestable),
      requestable_context: secondary_target_label(requestable),
      requested_access_level: access_request.requested_access_level,
      reason_preview: preview_text(access_request.reason),
      status: access_request.status,
      admin_review_path: admin_access_requests_path(status: "pending", q: access_request.public_id)
    }
  end

  def requester_preview(requester)
    [requester.name.presence, requester.email_address.presence].compact.join(" / ")
  end

  def primary_target_label(requestable)
    requestable[:name].presence || requestable[:title].presence || requestable[:file_name].presence || requestable[:public_id]
  end

  def secondary_target_label(requestable)
    return requestable[:code] if requestable[:code].present?
    return requestable[:project_code] if requestable[:project_code].present?
    return requestable[:document_title] if requestable[:document_title].present?

    nil
  end

  def preview_text(value)
    value.to_s.squish.truncate(REASON_PREVIEW_LENGTH, omission: "...")
  end

  def pending_handoff_note(total_count)
    if total_count.zero?
      "現在条件で pending handoff 対象はありません。正常保証、通知正常、全期間0件を意味しません。"
    else
      "現在条件に一致する pending 申請候補の read-only handoff です。承認・却下・通知・担当割当は実行しません。"
    end
  end

  def rejection_reason_param
    direct_reason = params[:rejection_reason].to_s.strip
    return direct_reason if direct_reason.present?

    preset_reason = REJECTION_REASON_PRESETS[params[:rejection_reason_preset].to_s]
    note = params[:rejection_reason_note].to_s.strip
    reason = [preset_reason, note.presence].compact.join("：")
    raise ApplicationError::BadRequest, "rejection_reason is required" if reason.blank?

    reason
  end

  def access_request_redirect_path
    safe_return_to_path || admin_access_requests_path(redirect_filter_params)
  end

  def safe_return_to_path
    return_to = params[:return_to].to_s.strip
    return nil if return_to.blank?
    return nil if return_to.match?(/[[:cntrl:]]/)
    return nil unless return_to.start_with?("/")
    return nil if return_to.start_with?("//") || return_to.include?("://")

    return_to
  end

  def redirect_filter_params
    page_params = filter_params.compact
    page = params[:page].to_i
    per_page = params[:per_page].to_i

    page_params[:page] = page if page.positive?
    page_params[:per_page] = [per_page, MAX_ADMIN_LIST_PER_PAGE].min if per_page.positive?
    page_params
  end

  def access_request_page_params
    page_params = @filters.transform_keys(&:to_s)
    page_params["page"] = @access_requests_pagination[:page] if params[:page].present?
    page_params["per_page"] = @access_requests_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def filter_params
    permitted = params.permit(:status, :q, :requested_access_level, :requestable_type).to_h.symbolize_keys
    status = permitted[:status].to_s
    requested_access_level = permitted[:requested_access_level].to_s
    requestable_type = permitted[:requestable_type].to_s

    {
      status: AccessRequest.statuses.key?(status) ? status : nil,
      q: normalized_query(permitted[:q]),
      requested_access_level: AccessRequest.requested_access_levels.key?(requested_access_level) ? requested_access_level : nil,
      requestable_type: AccessRequest::SUPPORTED_REQUESTABLE_TYPES.include?(requestable_type) ? requestable_type : nil
    }
  end

  def normalized_query(query)
    query.to_s.strip.presence&.slice(0, ACCESS_REQUEST_QUERY_MAX_LENGTH)
  end

  def admin_access_request_query_max_length
    ACCESS_REQUEST_QUERY_MAX_LENGTH
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def access_request_maintenance_message
    "メンテナンス中のためアクセス申請の承認と却下は停止しています。一覧、詳細、pending handoff の確認は継続できます。"
  end
end
