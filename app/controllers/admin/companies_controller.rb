class Admin::CompaniesController < Admin::BaseController
  before_action :set_company, only: %i[edit update destroy]
  before_action :require_company_master_admin_access!
  before_action :require_admin_only!, only: %i[create destroy]
  before_action :ensure_admin_master_maintenance_writable!, only: %i[create update destroy]

  helper_method :company_return_to_path

  def index
    @companies = filtered_companies
    @company = admin_user? ? Company.new(active: true) : current_user.company
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to admin_companies_path, notice: "会社を登録しました。"
    else
      @companies = filtered_companies
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to company_return_to_path, notice: "会社を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy!
    redirect_to company_return_to_path, notice: "会社を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to company_return_to_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to company_return_to_path, alert: "関連データがあるため削除できません。"
  end

  private

  def filtered_companies
    @company_filter_params = company_filter_params
    @companies_total_count = company_scope.count

    filtered_scope = company_scope.then { |scope| apply_company_filters(scope) }
    @companies_filtered_count = filtered_scope.count
    companies, @companies_pagination = paginate_admin_list(filtered_scope.order(:domain), @companies_filtered_count)
    @company_page_params = company_page_params

    companies
  end

  def apply_company_filters(scope)
    scope = filter_companies_by_keyword(scope)
    filter_companies_by_active(scope)
  end

  def filter_companies_by_keyword(scope)
    keyword = @company_filter_params["q"].to_s.strip
    return scope if keyword.blank?

    pattern = "%#{Company.sanitize_sql_like(keyword.downcase)}%"
    scope.where(
      "LOWER(companies.domain) LIKE :keyword OR LOWER(companies.name) LIKE :keyword",
      keyword: pattern
    )
  end

  def filter_companies_by_active(scope)
    case @company_filter_params["active"]
    when "true"
      scope.where(active: true)
    when "false"
      scope.where(active: false)
    else
      scope
    end
  end

  def company_filter_params
    params.permit(:q, :active).to_h
  end

  def company_page_params
    page_params = @company_filter_params.dup
    page_params["per_page"] = @companies_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def set_company
    @company = company_scope.find_by!(public_id: params[:public_id])
  end

  def company_return_to_path
    safe_return_to_path(admin_companies_path)
  end

  def company_params
    params.require(:company).permit(:domain, :name, :active)
  end

  def ensure_admin_master_maintenance_writable!
    return unless read_only_maintenance_mode?

    redirect_to company_return_to_path, alert: admin_master_maintenance_message
  end

  def require_company_master_admin_access!
    raise ApplicationError::Forbidden unless company_master_admin?
  end

  def company_scope
    return Company.all if admin_user?

    Company.where(id: current_user.company_id)
  end
end
