class Admin::ProjectMembershipsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project_membership, only: %i[edit update destroy]

  DEFAULT_PAGE_SIZE = 25
  MAX_PAGE_SIZE = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  USER_SEARCH_QUERY_MAX_LENGTH = 100
  USER_SEARCH_LIMIT = 20

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

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def user_search
    render json: { options: user_options(searchable_users) }
  end

  def selected_user
    user = User.find_by(id: params[:id])

    render json: { option: user ? user_option(user) : nil }
  end

  private

  def set_project_membership
    @project_membership = ProjectMembership.find_by!(public_id: params[:public_id])
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

  def searchable_users
    scope = User.order(:email_address, :id)
    query = normalize_user_search_query(params[:q])
    return scope.limit(USER_SEARCH_LIMIT) if query.blank?

    pattern = "%#{User.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(users.email_address) LIKE :pattern OR LOWER(users.name) LIKE :pattern",
      pattern:
    ).limit(USER_SEARCH_LIMIT)
  end

  def normalize_project_search_query(value)
    value.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_user_search_query(value)
    value.to_s.strip.first(USER_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.project_membership_project_option_label(project) }
  end

  def user_options(users)
    users.map { |user| user_option(user) }
  end

  def user_option(user)
    { value: user.id, text: helpers.project_membership_user_option_label(user) }
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
