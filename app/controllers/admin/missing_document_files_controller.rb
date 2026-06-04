class Admin::MissingDocumentFilesController < Admin::BaseController
  DETAIL_LIMIT = 100

  before_action :require_admin_only!

  def show
    @display_limit = DETAIL_LIMIT
    @projects = Project.order(:name, :code, :id)
    @missing_document_file_filters = missing_document_file_filters
    @selected_project = selected_project_for_filter
    @document_file_health = DocumentFileHealthCheck.new.call(
      limit: DETAIL_LIMIT,
      filters: @missing_document_file_filters
    )
  end

  private

  def missing_document_file_filters
    {
      project_id: params[:project_id].presence,
      document_q: params[:document_q].to_s.strip.presence,
      file_q: params[:file_q].to_s.strip.presence
    }
  end

  def selected_project_for_filter
    return if @missing_document_file_filters[:project_id].blank?

    @projects.find { |project| project.id.to_s == @missing_document_file_filters[:project_id].to_s }
  end
end
