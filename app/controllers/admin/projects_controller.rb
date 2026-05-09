class Admin::ProjectsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project, only: %i[edit update destroy]
  before_action :set_companies, only: %i[index create edit update]

  def index
    @projects = Project.includes(:company).order(:code)
    @project = Project.new(active: true)
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to admin_projects_path, notice: "案件を登録しました。"
    else
      @projects = Project.includes(:company).order(:code)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @template_plan_hash = ProjectTemplatePlanHash.new(ProjectTemplatePlan.new(project: @project).call).call
  end

  def update
    if @project.update(project_params)
      redirect_to admin_projects_path, notice: "案件を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to admin_projects_path, notice: "案件を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_projects_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to admin_projects_path, alert: "関連データがあるため削除できません。"
  end

  private

  def set_project
    @project = Project.find_by!(code: params[:id])
  end

  def set_companies
    @companies = Company.order(:domain)
  end

  def project_params
    params.require(:project).permit(:code, :name, :description, :active, :company_id)
  end
end
