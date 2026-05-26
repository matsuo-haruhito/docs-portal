class Admin::DashboardController < Admin::BaseController
  before_action :redirect_company_master_admin_to_allowed_surface!, only: :index
  before_action :require_admin_only!, only: :index

  def index
    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries.first(8)
  end

  private

  def redirect_company_master_admin_to_allowed_surface!
    return unless current_user&.company_master_admin?

    redirect_to admin_companies_path
  end
end
