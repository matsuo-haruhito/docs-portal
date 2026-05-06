class Admin::GitImportRunsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @git_import_runs = GitImportRun.includes(:git_import_source).order(created_at: :desc, id: :desc).limit(100)
  end
end
