class Admin::AccessRequestsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @filters = filter_params
    scope = filtered_access_request_scope
    @access_requests = filtered_access_requests(scope)
    @status_counts = access_request_status_counts(scope, @access_requests)
  end

  def update
    access_request = AccessRequest.find_by!(public_id: params[:public_id])
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

    redirect_to admin_access_requests_path, notice:
  end

  private

  def filtered_access_request_scope
    scope = AccessRequest.recent_first.includes(:requester, :approver, :requestable)
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope
  end

  def filtered_access_requests(scope)
    requests = scope.to_a
    return requests unless @filters[:q].present?

    requests.select { |access_request| access_request_matches_query?(access_request, @filters[:q]) }
  end

  def access_request_matches_query?(access_request, query)
    access_request_search_text(access_request).include?(query.downcase)
  end

  def access_request_search_text(access_request)
    request_hash = AccessRequestHash.new(access_request).call
    requestable = request_hash[:requestable] || {}

    [
      request_hash.dig(:requester, :name),
      request_hash.dig(:requester, :email_address),
      request_hash[:reason],
      requestable[:type],
      requestable[:code],
      requestable[:name],
      requestable[:project_code],
      requestable[:title],
      requestable[:document_title],
      requestable[:file_name],
      requestable[:public_id]
    ].compact.join(" ").downcase
  end

  def access_request_status_counts(scope, access_requests)
    return access_request_status_counts_from_loaded(access_requests) if @filters[:q].present?

    counts = scope.unscope(:order).group(:status).count
    AccessRequest.statuses.keys.to_h do |status|
      [status, counts[status].to_i]
    end
  end

  def access_request_status_counts_from_loaded(access_requests)
    AccessRequest.statuses.keys.to_h do |status|
      [status, access_requests.count { |access_request| access_request.status == status }]
    end
  end

  def rejection_reason_param
    reason = params[:rejection_reason].to_s.strip
    raise ApplicationError::BadRequest, "rejection_reason is required" if reason.blank?

    reason
  end

  def filter_params
    permitted = params.permit(:status, :q).to_h.symbolize_keys
    status = permitted[:status].to_s

    {
      status: AccessRequest.statuses.key?(status) ? status : nil,
      q: permitted[:q].to_s.strip.presence
    }
  end
end
