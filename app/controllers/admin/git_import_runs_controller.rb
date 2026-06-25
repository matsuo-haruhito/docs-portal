class Admin::GitImportRunsController < Admin::BaseController
  before_action :require_admin_only!

  GIT_IMPORT_RUN_LIMIT = 100

  def index
    @has_git_import_runs = GitImportRun.exists?
    @status_filter = permitted_status_filter
    @repository_filter = params[:repository].to_s.strip
    @branch_filter = params[:branch].to_s.strip
    @source_path_filter = params[:source_path].to_s.strip
    @commit_filter = params[:commit].to_s.strip
    @git_import_run_filters_active = [
      @status_filter,
      @repository_filter,
      @branch_filter,
      @source_path_filter,
      @commit_filter
    ].any?(&:present?)

    @git_import_runs = filtered_git_import_runs.limit(GIT_IMPORT_RUN_LIMIT)
  end

  private

  def filtered_git_import_runs
    runs = GitImportRun.includes(:git_import_source).order(created_at: :desc, id: :desc)
    runs = runs.where(status: GitImportRun.statuses.fetch(@status_filter)) if @status_filter.present?
    runs = apply_text_filter(runs, :repository_full_name, @repository_filter) if @repository_filter.present?
    runs = apply_text_filter(runs, :branch, @branch_filter) if @branch_filter.present?
    runs = apply_text_filter(runs, :source_path, @source_path_filter) if @source_path_filter.present?

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

  def permitted_status_filter
    status = params[:status].to_s
    GitImportRun.statuses.key?(status) ? status : nil
  end
end
