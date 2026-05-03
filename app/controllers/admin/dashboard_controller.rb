class Admin::DashboardController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @document_file_health = DocumentFileHealthCheck.new.call
  end
end
