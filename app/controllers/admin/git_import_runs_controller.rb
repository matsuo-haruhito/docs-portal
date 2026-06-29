class Admin::GitImportRunsController < Admin::BaseController
  before_action :require_admin_only!

  GIT_IMPORT_RUN_LIMIT = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  def index
    @has_git_import_runs = GitImportRun.exists?
    @status_filter = permitted_status_filter
    @repository_filter = params[:repository].to_s.strip
    @branch_filter = params[:branch].to_s.strip
    @source_path_filter = params[:source_path].to_s.strip
    @commit_filter = params[:commit].to_s.strip
    @selected_project = selected_filter_project
    @selected_project_id = @selected_project&.id
    @git_import_run_filters_active = [
      @status_filter,
      @repository_filter,
      @branch_filter,
      @source_path_filter,
      @commit_filter,
      @selected_project_id
    ].any?(&:present?)

    @git_import_runs = filtered_git_import_runs.limit(GIT_IMPORT_RUN_LIMIT)
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def filtered_git_import_runs
    runs = GitImportRun.includes(git_import_source: :project).order(created_at: :desc, id: :desc)
    runs = runs.where(status: GitImportRun.statuses.fetch(@status_filter)) if @status_filter.present?
    runs = apply_text_filter(runs, :repository_full_name, @repository_filter) if @repository_filter.present?
    runs = apply_text_filter(runs, :branch, @branch_filter) if @branch_filter.present?
    runs = apply_text_filter(runs, :source_path, @source_path_filter) if @source_path_filter.present?
    runs = runs.joins(:git_import_source).where(git_import_sources: { project_id: @selected_project_id }) if @selected_project_id.present?

    if @commit_filter.present?
      commit_query = GitImportRun.sanitize_sql_like(@commit_filter.downcase)
      runs = runs.where("LOWER(git_import_runs.commit_sha) LIKE ?", "#{commit_query}%")
    end

    runs
  end

  def apply_text_filter(runs, column, value)
    query = GitImportRun.sanitize_sql_like(value.downcase)
    runs.where("LOWER(git_import_runs.#{column}) LIKE ?", "%#{query}%")
  end

  def selected_filter_project
    Project.find_by(id: params[:project_id]) if params[:project_id].present?
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
    { value: project.id, text: helpers.git_import_run_project_option_label(project) }
  end

  def permitted_status_filter
    status = params[:status].to_s
    GitImportRun.statuses.key?(status) ? status : nil
  end
end
