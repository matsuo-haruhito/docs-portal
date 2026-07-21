class Admin::GitImportSourcesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_git_import_source, only: %i[edit update destroy sync]
  before_action :block_git_import_source_mutation_during_maintenance!, only: %i[create update destroy]

  GIT_IMPORT_SOURCE_QUERY_MAX_LENGTH = 100
  GIT_IMPORT_SOURCE_PER_PAGE = 50
  GIT_IMPORT_SOURCE_MAX_PER_PAGE = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  REPOSITORY_SEARCH_LIMIT = 20
  BRANCH_SEARCH_LIMIT = 20
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def index
    load_index_state
    @git_import_source = GitImportSource.new(branch: "main", source_path: "docs", auth_type: :github_app, enabled: true)
  end

  def create
    @git_import_source = GitImportSource.new(git_import_source_params)
    @git_import_source.created_by = current_user

    if @git_import_source.save
      redirect_to admin_git_import_sources_path, notice: "Git連携設定を登録しました。"
    else
      load_index_state
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
    if read_only_maintenance_mode?
      redirect_to edit_admin_git_import_source_path(@git_import_source), alert: maintenance_sync_message
      return
    end

    run = GitImportSourceSyncer.new(source: @git_import_source, actor: current_user).call
    redirect_to admin_git_import_runs_path, notice: "Git同期を実行しました。status=#{run.status}"
  rescue => e
    redirect_to admin_git_import_sources_path, alert: "Git同期に失敗しました: #{e.message}"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def repository_search
    if params[:kind] == "branch"
      render_branch_search
      return
    end

    result = GitHubAppRepositoryOptions.new(
      installation_id: params[:installation_id],
      query: params[:q],
      limit: REPOSITORY_SEARCH_LIMIT
    ).call

    render json: {
      options: repository_options(result.repositories),
      fallback: result.fallback?,
      message: result.message
    }
  end

  def selected_repository
    repository_full_name = normalize_repository_full_name(params[:id])

    render json: { option: repository_full_name ? repository_option(repository_full_name) : nil }
  end

  private

  def set_git_import_source
    @git_import_source = GitImportSource.find_by!(public_id: params[:public_id])
  end

  def block_git_import_source_mutation_during_maintenance!
    return unless read_only_maintenance_mode?

    redirect_to admin_git_import_sources_path, alert: git_import_source_maintenance_message
  end

  def load_index_state
    @query = normalize_git_import_source_query(params[:q])
    @selected_project = selected_filter_project
    @selected_project_id = @selected_project&.id
    @selected_enabled = normalize_enabled_filter(params[:enabled])
    @git_import_sources_per_page = normalize_per_page(params[:per_page])
    @git_import_source_page_params = {
      q: @query.presence,
      project_id: @selected_project_id,
      enabled: @selected_enabled.presence,
      per_page: (@git_import_sources_per_page == GIT_IMPORT_SOURCE_PER_PAGE ? nil : @git_import_sources_per_page)
    }.compact

    base_scope = git_import_sources_scope
    @git_import_sources_total_count = base_scope.count
    filtered_scope = filter_git_import_sources_scope(base_scope)
    @git_import_sources_filtered_count = filtered_scope.count
    @git_import_sources_page = normalized_page(params[:page], @git_import_sources_filtered_count, @git_import_sources_per_page)
    @git_import_sources_pagination = pagination_metadata(
      page: @git_import_sources_page,
      per_page: @git_import_sources_per_page,
      filtered_count: @git_import_sources_filtered_count
    )
    @git_import_sources = filtered_scope
      .offset(@git_import_sources_pagination[:offset])
      .limit(@git_import_sources_per_page)
  end

  def git_import_sources_scope
    GitImportSource.includes(:project, :created_by).order(:repository_full_name, :branch, :source_path)
  end

  def filter_git_import_sources_scope(scope)
    filtered = scope
    filtered = apply_git_import_source_query_filter(filtered)
    filtered = filtered.where(project_id: @selected_project_id) if @selected_project_id.present?
    filtered = filtered.where(enabled: @selected_enabled == "true") if @selected_enabled.present?
    filtered
  end

  def apply_git_import_source_query_filter(scope)
    return scope if @query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
    scope.where(
      <<~SQL.squish,
        LOWER(git_import_sources.repository_full_name) LIKE :pattern OR
        LOWER(git_import_sources.branch) LIKE :pattern OR
        LOWER(git_import_sources.source_path) LIKE :pattern
      SQL
      pattern:
    )
  end

  def selected_filter_project
    Project.find_by(id: params[:project_id]) if params[:project_id].present?
  end

  def normalize_git_import_source_query(query)
    query.to_s.squish.first(GIT_IMPORT_SOURCE_QUERY_MAX_LENGTH).presence
  end

  def normalize_enabled_filter(value)
    value.to_s.presence_in(%w[true false])
  end

  def normalize_per_page(value)
    per_page = value.to_i
    per_page = GIT_IMPORT_SOURCE_PER_PAGE unless per_page.positive?
    [per_page, GIT_IMPORT_SOURCE_MAX_PER_PAGE].min
  end

  def normalized_page(value, filtered_count, per_page)
    page = value.to_i
    page = 1 unless page.positive?
    total_pages = [(filtered_count.to_f / per_page).ceil, 1].max
    [page, total_pages].min
  end

  def pagination_metadata(page:, per_page:, filtered_count:)
    total_pages = [(filtered_count.to_f / per_page).ceil, 1].max
    offset = (page - 1) * per_page
    displayed_count = [filtered_count - offset, per_page].min.clamp(0, per_page)

    {
      page:,
      per_page:,
      offset:,
      total_pages:,
      from: displayed_count.positive? ? offset + 1 : 0,
      to: displayed_count.positive? ? offset + displayed_count : 0,
      prev_page: (page > 1 ? page - 1 : nil),
      next_page: (page < total_pages ? page + 1 : nil)
    }
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

  def render_branch_search
    result = GitHubAppBranchOptions.new(
      installation_id: params[:installation_id],
      repository_full_name: params[:repository_full_name],
      query: params[:q],
      limit: BRANCH_SEARCH_LIMIT
    ).call

    render json: {
      options: branch_options(result.branches),
      fallback: result.fallback?,
      message: result.message
    }
  end

  def normalize_repository_full_name(value)
    repository_full_name = value.to_s.strip.first(GIT_IMPORT_SOURCE_QUERY_MAX_LENGTH)
    return nil unless repository_full_name.match?(%r{\A[\w.-]+/[\w.-]+\z})

    repository_full_name
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.git_import_source_project_option_label(project) }
  end

  def repository_options(repositories)
    repositories.map { |repository_full_name| repository_option(repository_full_name) }
  end

  def repository_option(repository_full_name)
    { value: repository_full_name, text: repository_full_name }
  end

  def branch_options(branches)
    branches.map { |branch| branch_option(branch) }
  end

  def branch_option(branch)
    { value: branch, text: branch }
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def git_import_source_maintenance_message
    "メンテナンス中のためGit連携設定の変更は停止しています。設定と同期履歴の閲覧は継続できます。"
  end

  def maintenance_sync_message
    "メンテナンス中のためGit手動同期は停止しています。Git連携設定と同期履歴の閲覧は継続できます。運用手順は本番運用・インフラ前提を確認してください。"
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
