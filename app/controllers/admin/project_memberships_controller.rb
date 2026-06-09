class Admin::ProjectMembershipsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project_membership, only: %i[edit update destroy]
  before_action :load_master_options, only: %i[index create edit update]

  DEFAULT_PAGE_SIZE = 25
  MAX_PAGE_SIZE = 100

  def index
    load_project_memberships_page
    @project_membership = ProjectMembership.new(role: :viewer)
  end

  def create
    @project_membership = ProjectMembership.new(project_membership_params)

    if @project_membership.save
      redirect_to admin_project_memberships_path, notice: "案件所属を登録しました。"
    else
      load_project_memberships_page
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

  def load_project_memberships_page
    scope = project_memberships_scope
    @project_memberships_total_count = scope.count
    @project_memberships_per_page = bounded_positive_integer_param(:per_page, default: DEFAULT_PAGE_SIZE, maximum: MAX_PAGE_SIZE)
    @project_memberships_total_pages = [(@project_memberships_total_count.to_f / @project_memberships_per_page).ceil, 1].max
    @project_memberships_page = bounded_positive_integer_param(:page, default: 1)
    @project_memberships_page = @project_memberships_total_pages if @project_memberships_page > @project_memberships_total_pages
    offset = (@project_memberships_page - 1) * @project_memberships_per_page
    @project_memberships = scope.offset(offset).limit(@project_memberships_per_page)
  end

  def project_memberships_scope
    ProjectMembership.joins(:project, :user).includes(:project, :user).order("projects.code", "users.email_address")
  end

  def bounded_positive_integer_param(name, default:, maximum: nil)
    value = Integer(params[name].to_s, exception: false)
    value = default if value.blank? || value <= 0
    maximum ? [value, maximum].min : value
  end

  def project_membership_params
    params.require(:project_membership).permit(:project_id, :user_id, :role)
  end
end
