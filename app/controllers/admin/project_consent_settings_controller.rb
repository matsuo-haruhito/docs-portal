class Admin::ProjectConsentSettingsController < Admin::BaseController
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  CONSENT_TERM_SEARCH_QUERY_MAX_LENGTH = 100
  CONSENT_TERM_SEARCH_LIMIT = 20

  before_action :require_admin_only!
  before_action :block_project_consent_setting_mutation_during_maintenance, only: %i[create update destroy]
  before_action :set_project_consent_setting, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @project_consent_settings = filtered_project_consent_settings
    @project_consent_setting = ProjectConsentSetting.new(enabled: true, required_on: :first_access)
  end

  def create
    @project_consent_setting = ProjectConsentSetting.new(project_consent_setting_params)

    if @project_consent_setting.save
      redirect_to admin_project_consent_settings_path, notice: "案件同意設定を登録しました。"
    else
      @project_consent_settings = filtered_project_consent_settings
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project_consent_setting.update(project_consent_setting_params)
      redirect_to admin_project_consent_settings_path, notice: "案件同意設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project_consent_setting.destroy!
    redirect_to admin_project_consent_settings_path, notice: "案件同意設定を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    redirect_to admin_project_consent_settings_path, alert: "関連データがあるため削除できません。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def consent_term_search
    render json: { options: consent_term_options(searchable_consent_terms) }
  end

  def selected_consent_term
    consent_term = ConsentTerm.active_only.find_by(id: params[:id])

    render json: { option: consent_term ? consent_term_option(consent_term) : nil }
  end

  private

  def block_project_consent_setting_mutation_during_maintenance
    return unless read_only_maintenance_mode?

    redirect_to admin_project_consent_settings_path, alert: maintenance_project_consent_setting_message
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_project_consent_setting_message
    "メンテナンス中のため案件同意設定の作成・更新・削除は停止しています。一覧、編集内容、検索は確認できます。"
  end

  def filtered_project_consent_settings
    @selected_project_id = project_filter_param
    @selected_consent_term_id = consent_term_filter_param
    @selected_enabled = enabled_filter_param

    base_scope = project_consent_settings_scope
    @project_consent_settings_total_count = base_scope.count
    filtered_scope = apply_project_consent_setting_filters(base_scope)
    @project_consent_settings_filtered_count = filtered_scope.count
    settings, @project_consent_settings_pagination = paginate_admin_list(
      filtered_scope,
      @project_consent_settings_filtered_count
    )
    @project_consent_setting_page_params = project_consent_setting_page_params
    @project_consent_settings_exist = @project_consent_settings_total_count.positive?

    settings
  end

  def apply_project_consent_setting_filters(scope)
    scope = scope.where(project_id: @selected_project_id) if @selected_project_id.present?
    scope = scope.where(consent_term_id: @selected_consent_term_id) if @selected_consent_term_id.present?
    scope = scope.where(enabled: @selected_enabled == "true") if @selected_enabled.present?
    scope
  end

  def project_consent_setting_page_params
    page_params = {
      project_id: @selected_project_id,
      consent_term_id: @selected_consent_term_id,
      enabled: @selected_enabled
    }
    page_params[:per_page] = @project_consent_settings_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def set_project_consent_setting
    @project_consent_setting = ProjectConsentSetting.find_by!(public_id: params[:public_id])
  end

  def load_form_collections
    @selected_project = Project.find_by(id: selected_project_id_for_option)
    @selected_consent_term = ConsentTerm.active_only.find_by(id: selected_consent_term_id_for_option)
  end

  def project_consent_settings_scope
    ProjectConsentSetting.joins(:project).includes(:project, :consent_term).order("projects.code", :required_on)
  end

  def project_filter_param
    filter_id_param(:project_id, Project)
  end

  def consent_term_filter_param
    filter_id_param(:consent_term_id, ConsentTerm.active_only)
  end

  def enabled_filter_param
    enabled = params[:enabled].to_s
    %w[true false].include?(enabled) ? enabled : nil
  end

  def filter_id_param(key, scope)
    id = params[key].to_s
    return nil if id.blank?

    scope.exists?(id:) ? id : nil
  end

  def selected_project_id_for_option
    params[:project_id].presence || params.dig(:project_consent_setting, :project_id).presence || @project_consent_setting&.project_id
  end

  def selected_consent_term_id_for_option
    params[:consent_term_id].presence || params.dig(:project_consent_setting, :consent_term_id).presence || @project_consent_setting&.consent_term_id
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

  def searchable_consent_terms
    scope = ConsentTerm.active_only.order(:title, :version_label, :id)
    query = normalize_consent_term_search_query(params[:q])
    return scope.limit(CONSENT_TERM_SEARCH_LIMIT) if query.blank?

    pattern = "%#{ConsentTerm.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(consent_terms.title) LIKE :pattern OR LOWER(consent_terms.version_label) LIKE :pattern",
      pattern:
    ).limit(CONSENT_TERM_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_consent_term_search_query(query)
    query.to_s.strip.first(CONSENT_TERM_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.project_consent_setting_project_option_label(project) }
  end

  def consent_term_options(consent_terms)
    consent_terms.map { |consent_term| consent_term_option(consent_term) }
  end

  def consent_term_option(consent_term)
    { value: consent_term.id, text: helpers.project_consent_term_option_label(consent_term) }
  end

  def project_consent_setting_params
    params.require(:project_consent_setting).permit(:project_id, :consent_term_id, :required_on, :enabled)
  end
end
