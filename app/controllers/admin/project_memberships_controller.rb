class Admin::ProjectMembershipsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project_membership, only: %i[edit update destroy]
  before_action :load_master_options, only: %i[index create edit update]

  def index
    @project_memberships = ProjectMembership.joins(:project, :user).includes(:project, :user).order("projects.code", "users.email_address")
    @project_membership = ProjectMembership.new(role: :viewer)
  end

  def create
    @project_membership = ProjectMembership.new(project_membership_params)

    if @project_membership.save
      redirect_to admin_project_memberships_path, notice: "案件所属を登録しました。"
    else
      @project_memberships = ProjectMembership.joins(:project, :user).includes(:project, :user).order("projects.code", "users.email_address")
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project_membership.update(project_membership_params)
      redirect_to admin_project_memberships_path, notice: "案件所属を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project_membership.destroy!
    redirect_to admin_project_memberships_path, notice: "案件所属を削除しました。"
  end

  private

  def set_project_membership
    @project_membership = ProjectMembership.find_by!(public_id: params[:public_id])
  end

  def load_master_options
    @projects = Project.order(:code)
    @users = User.order(:email_address)
  end

  def project_membership_params
    params.require(:project_membership).permit(:project_id, :user_id, :role)
  end
end