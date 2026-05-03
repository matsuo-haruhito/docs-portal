class Admin::BaseController < BaseController
  before_action :require_admin_area_access!

  private

  def require_admin_area_access!
    raise ApplicationError::Forbidden unless admin_user? || company_master_admin?
  end

  def require_admin_only!
    raise ApplicationError::Forbidden unless admin_user?
  end
end
