class Admin::ProjectConsentSettingsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project_consent_setting, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @project_consent_settings = project_consent_settings_scope
    @project_consent_setting = ProjectConsentSetting.new(enabled: true, required_on: :first_access)
  end

  def create
    @project_consent_setting = ProjectConsentSetting.new(project_consent_setting_params)

    if @project_consent_setting.save
      redirect_to admin_project_consent_settings_path, notice: "案件同意設定を登録しました。"
    else
      @project_consent_settings = project_consent_settings_scope
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

  def project_consent_setting_params
    params.require(:project_consent_setting).permit(:project_id, :consent_term_id, :required_on, :enabled)
  end
end
