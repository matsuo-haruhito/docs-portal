class Admin::DashboardController < Admin::BaseController
  before_action :require_internal_admin_for_dashboard!, only: :index

  def index
    return if current_user&.company_master_admin?

    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries.first(8)
  end

  private

  def require_internal_admin_for_dashboard!
    return if current_user&.company_master_admin?

    require_admin_only!
  end
end
