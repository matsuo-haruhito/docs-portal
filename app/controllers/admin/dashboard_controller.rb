class Admin::DashboardController < Admin::BaseController
  before_action :require_admin_only!

  def index
  end
end
