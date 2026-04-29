class Admin::BaseController < BaseController
  before_action :require_admin!

  private

  def require_admin!
    raise ApplicationError::Forbidden unless admin_user?
  end
end
