class Admin::ProjectsController < Admin::BaseController
  COMPANY_SEARCH_LIMIT = 20
  COMPANY_SEARCH_QUERY_MAX_LENGTH = 100

  before_action :require_admin_only!
  before_action :set_project, only: %i[edit update destroy]

  def index
    @projects = filtered_projects
    @project = Project.new(active: true)
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to admin_projects_path, notice: "案件を登録しました。"
    else
      @projects = filtered_projects
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

  def company_search
    render json: { options: project_company_options(searchable_project_companies) }
  end

  def selected_company
    company = selected_project_company(params[:id])

    render json: { option: company ? project_company_option(company) : nil }
  end

  private

  def filtered_projects
    @project_filter_params = project_filter_params
    @selected_project_company = selected_project_company(@project_filter_params["company_id"])
    @projects_total_count = Project.count

    Project.includes(:company).then { |scope| apply_project_filters(scope) }.order(:code)
  end

  def apply_project_filters(scope)
    scope = filter_projects_by_keyword(scope)
    scope = filter_projects_by_active(scope)
    filter_projects_by_company(scope)
  end

  def filter_projects_by_keyword(scope)
    keyword = @project_filter_params["q"].to_s.strip
    return scope if keyword.blank?

    pattern = "%#{Project.sanitize_sql_like(keyword.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :keyword OR LOWER(projects.name) LIKE :keyword OR LOWER(projects.description) LIKE :keyword",
      keyword: pattern
    )
  end

  def filter_projects_by_active(scope)
    case @project_filter_params["active"]
    when "true"
      scope.where(active: true)
    when "false"
      scope.where(active: false)
    else
      scope
    end
  end

  def filter_projects_by_company(scope)
    company_id = @project_filter_params["company_id"].to_s

    if company_id == "none"
      scope.where(company_id: nil)
    elsif company_id.match?(/\A\d+\z/)
      scope.where(company_id: company_id)
    else
      scope
    end
  end

  def project_filter_params
    params.permit(:q, :active, :company_id).to_h
  end

  def set_project
    @project = Project.find_by!(code: project_code_param)
  end

  def project_code_param
    params[:code] || params[:id]
  end

  def searchable_project_companies
    scope = Company.order(:domain, :id)
    query = normalized_company_search_query(params[:q])
    return scope.limit(COMPANY_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Company.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(companies.domain) LIKE :pattern OR LOWER(companies.name) LIKE :pattern",
      pattern:
    ).limit(COMPANY_SEARCH_LIMIT)
  end

  def selected_project_company(company_id)
    return unless company_id.to_s.match?(/\A\d+\z/)

    Company.find_by(id: company_id)
  end

  def normalized_company_search_query(value)
    value.to_s.strip.first(COMPANY_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_company_options(companies)
    companies.map { project_company_option(_1) }
  end

  def project_company_option(company)
    { value: company.id, text: helpers.admin_project_company_option_label(company) }
  end

  def project_params
    params.require(:project).permit(:code, :name, :description, :active, :company_id)
  end
end