class Admin::MissingDocumentFilesController < Admin::BaseController
  DETAIL_LIMIT = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  before_action :require_admin_only!

  def show
    @display_limit = DETAIL_LIMIT
    @missing_document_file_filters = missing_document_file_filters
    @selected_project = selected_project_for_filter
    @document_file_health = DocumentFileHealthCheck.new.call(
      limit: DETAIL_LIMIT,
      filters: @missing_document_file_filters
    )

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          helpers.missing_document_file_handoff_csv(@document_file_health),
          filename: missing_document_files_csv_filename,
          type: "text/csv; charset=utf-8"
        )
      end
    end
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def missing_document_file_filters
    {
      project_id: project_filter_project&.id,
      document_q: params[:document_q].to_s.strip.presence,
      file_q: params[:file_q].to_s.strip.presence
    }
  end

  def selected_project_for_filter
    return if @missing_document_file_filters[:project_id].blank?

    project_filter_project
  end

  def project_filter_project
    return @project_filter_project if defined?(@project_filter_project)

    project_id = params[:project_id].presence
    @project_filter_project = project_id.present? ? Project.find_by(id: project_id) : nil
  end

  def missing_document_files_csv_filename
    "missing-document-files-#{Time.zone.today.iso8601}.csv"
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.missing_document_file_project_option_label(project) }
  end
end
