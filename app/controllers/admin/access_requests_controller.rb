class Admin::AccessRequestsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @access_requests = AccessRequest.recent_first.includes(:requester, :approver, :requestable)
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

  def rejection_reason_param
    reason = params[:rejection_reason].to_s.strip
    raise ApplicationError::BadRequest, "rejection_reason is required" if reason.blank?

    reason
  end
end
