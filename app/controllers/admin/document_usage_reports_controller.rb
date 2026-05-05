class Admin::DocumentUsageReportsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @report_hash = build_report_hash(@selected_project) if @selected_project
  end

  private

  def selected_project
    return if params[:project_id].blank?

    @projects.find_by(id: params[:project_id])
  end

  def build_report_hash(project)
    result = DocumentUsageReport.new(project:).call
    DocumentUsageReportHash.new(result).call
  end
end
