class Admin::GitImportSourcesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_git_import_source, only: %i[edit update destroy sync]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @git_import_sources = git_import_sources_scope
    @git_import_source = GitImportSource.new(branch: "main", source_path: "docs", auth_type: :github_app, enabled: true)
  end

  def create
    @git_import_source = GitImportSource.new(git_import_source_params)
    @git_import_source.created_by = current_user

    if @git_import_source.save
      redirect_to admin_git_import_sources_path, notice: "Git連携設定を登録しました。"
    else
      @git_import_sources = git_import_sources_scope
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = git_import_source_params
    attrs.delete(:credential_secret) if attrs[:credential_secret].blank?

    if @git_import_source.update(attrs)
      redirect_to admin_git_import_sources_path, notice: "Git連携設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @git_import_source.destroy!
    redirect_to admin_git_import_sources_path, notice: "Git連携設定を削除しました。"
  end

  def sync
    run = GitImportSourceSyncer.new(source: @git_import_source, actor: current_user).call
    redirect_to admin_git_import_runs_path, notice: "Git同期を実行しました。status=#{run.status}"
  rescue => e
    redirect_to admin_git_import_sources_path, alert: "Git同期に失敗しました: #{e.message}"
  end

  private

  def set_git_import_source
    @git_import_source = GitImportSource.find_by!(public_id: params[:id])
  end

  def load_form_collections
    @projects = Project.order(:code)
  end

  def git_import_sources_scope
    GitImportSource.includes(:project, :created_by).order(:repository_full_name, :branch, :source_path)
  end

  def git_import_source_params
    params.require(:git_import_source).permit(
      :project_id,
      :provider,
      :organization_name,
      :repository_full_name,
      :branch,
      :source_path,
      :auth_type,
      :installation_id,
      :credential_ref,
      :credential_secret,
      :enabled
    )
  end
end
