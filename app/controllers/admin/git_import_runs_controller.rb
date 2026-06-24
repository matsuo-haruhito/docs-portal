class Admin::GitImportRunsController < Admin::BaseController
  before_action :require_admin_only!

  GIT_IMPORT_RUN_LIMIT = 100

  def index
    @has_git_import_runs = GitImportRun.exists?
    @status_filter = permitted_status_filter
    @repository_filter = text_filter_param(:repository)
    @branch_filter = text_filter_param(:branch)
    @source_path_filter = text_filter_param(:source_path)
    @commit_sha_filter = text_filter_param(:commit_sha)
    @git_import_run_filters_active = [
      @status_filter,
      @repository_filter,
      @branch_filter,
      @source_path_filter,
      @commit_sha_filter
    ].any?(&:present?)

    @git_import_runs = filtered_git_import_runs.limit(GIT_IMPORT_RUN_LIMIT)
  end

  private

  def filtered_git_import_runs
    runs = GitImportRun.includes(:git_import_source).order(created_at: :desc, id: :desc)
    runs = runs.where(status: GitImportRun.statuses.fetch(@status_filter)) if @status_filter.present?
    runs = apply_text_filter(runs, column: "repository_full_name", value: @repository_filter)
    runs = apply_text_filter(runs, column: "branch", value: @branch_filter)
    runs = apply_text_filter(runs, column: "source_path", value: @source_path_filter)
    runs = apply_text_filter(runs, column: "commit_sha", value: @commit_sha_filter, match: :prefix)

    runs
  end

  def apply_text_filter(scope, column:, value:, match: :contains)
    return scope if value.blank?

    escaped_value = GitImportRun.sanitize_sql_like(value.downcase)
    pattern = match == :prefix ? "#{escaped_value}%" : "%#{escaped_value}%"
    scope.where("LOWER(git_import_runs.#{column}) LIKE ?", pattern)
  end

  def text_filter_param(key)
    params[key].to_s.strip
  end

  def permitted_status_filter
    status = params[:status].to_s
    GitImportRun.statuses.key?(status) ? status : nil
  end
end
