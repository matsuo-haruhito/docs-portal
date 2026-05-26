class Admin::AccessRequestsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @filters = filter_params
    @access_requests = filtered_access_requests
    @status_counts = access_request_status_counts(@access_requests)
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

  def filtered_access_requests
    requests = AccessRequest.recent_first.includes(:requester, :approver, :requestable).to_a
    requests = requests.select { |access_request| access_request.status == @filters[:status] } if @filters[:status].present?
    requests = requests.select { |access_request| access_request_matches_query?(access_request, @filters[:q]) } if @filters[:q].present?
    requests
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

  def access_request_status_counts(access_requests)
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
