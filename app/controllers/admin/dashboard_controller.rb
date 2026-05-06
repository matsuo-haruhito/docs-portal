class Admin::DashboardController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries.first(8)
  end
end
