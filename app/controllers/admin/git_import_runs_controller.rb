class Admin::GitImportRunsController < Admin::BaseController
  before_action :require_admin_only!

  GIT_IMPORT_RUN_LIMIT = 100

  def index
    @has_git_import_runs = GitImportRun.exists?
    @status_filter = permitted_status_filter
    @repository_filter = params[:repository].to_s.strip
    @git_import_run_filters_active = @status_filter.present? || @repository_filter.present?

    @git_import_runs = filtered_git_import_runs.limit(GIT_IMPORT_RUN_LIMIT)
  end

  private

  def filtered_git_import_runs
    runs = GitImportRun.includes(:git_import_source).order(created_at: :desc, id: :desc)
    runs = runs.where(status: GitImportRun.statuses.fetch(@status_filter)) if @status_filter.present?

    if @repository_filter.present?
      repository_query = GitImportRun.sanitize_sql_like(@repository_filter.downcase)
      runs = runs.where("LOWER(git_import_runs.repository_full_name) LIKE ?", "%#{repository_query}%")
    end

    runs
  end

  def permitted_status_filter
    status = params[:status].to_s
    GitImportRun.statuses.key?(status) ? status : nil
  end
end
