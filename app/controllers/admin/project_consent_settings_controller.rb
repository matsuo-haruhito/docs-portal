class Admin::ProjectConsentSettingsController < Admin::BaseController
  before_action :require_admin_only!
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

  private

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
    @projects = Project.order(:code)
    @consent_terms = ConsentTerm.active_only.order(:title, :version_label)
  end

  def project_consent_settings_scope
    ProjectConsentSetting.joins(:project).includes(:project, :consent_term).order("projects.code", :required_on)
  end

  def project_filter_param
    filter_id_param(:project_id, @projects)
  end

  def consent_term_filter_param
    filter_id_param(:consent_term_id, @consent_terms)
  end

  def enabled_filter_param
    enabled = params[:enabled].to_s
    %w[true false].include?(enabled) ? enabled : nil
  end

  def filter_id_param(key, collection)
    id = params[key].to_s
    return nil if id.blank?

    collection.any? { |record| record.id.to_s == id } ? id : nil
  end

  def project_consent_setting_params
    params.require(:project_consent_setting).permit(:project_id, :consent_term_id, :required_on, :enabled)
  end
end
