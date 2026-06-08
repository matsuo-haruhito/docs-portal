class Admin::BaseController < BaseController
  before_action :require_admin_area_access!

  private

  def require_admin_area_access!
    raise ApplicationError::Forbidden unless admin_user? || company_master_admin?
  end

  def require_admin_only!
    raise ApplicationError::Forbidden unless admin_user?
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
