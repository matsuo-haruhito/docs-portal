class Admin::GitImportRunsController < Admin::BaseController
  MAX_RUNS = 100

  before_action :require_admin_only!

  def index
    @filters = filter_params
    @git_import_runs_exist = GitImportRun.exists?
    @git_import_runs = filtered_git_import_runs
  end

  private

  def filtered_git_import_runs
    scope = GitImportRun.includes(:git_import_source)
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?

    if @filters[:repository_q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:repository_q])}%"
      scope = scope.where("repository_full_name LIKE ?", query)
    end

    scope.order(created_at: :desc, id: :desc).limit(MAX_RUNS)
  end

  def filter_params
    permitted = params.permit(:status, :repository_q)
    permitted[:status] = nil unless GitImportRun.statuses.key?(permitted[:status])
    permitted[:repository_q] = permitted[:repository_q].to_s.strip.presence
    permitted
  end
end
