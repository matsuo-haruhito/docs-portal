class Admin::CompaniesController < Admin::BaseController
  before_action :set_company, only: %i[edit update destroy]
  before_action :require_company_master_admin_access!
  before_action :require_admin_only!, only: %i[create destroy]

  def index
    @companies = company_scope.order(:domain)
    @company = company_master_admin? ? current_user.company : Company.new(active: true)
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to admin_companies_path, notice: "会社を登録しました。"
    else
      @companies = company_scope.order(:domain)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to admin_companies_path, notice: "会社を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy!
    redirect_to admin_companies_path, notice: "会社を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_companies_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to admin_companies_path, alert: "関連データがあるため削除できません。"
  end

  private

  def set_company
    @company = company_scope.find(params[:id])
  end

  def company_params
    permitted = params.require(:company).permit(:domain, :code, :name, :active)
    permitted[:domain] = permitted[:code] if permitted[:domain].blank? && permitted[:code].present?
    permitted.except(:code)
  end

  def require_company_master_admin_access!
    raise ApplicationError::Forbidden unless company_master_admin?
  end

  def company_scope
    return Company.all if admin_user?

    Company.where(id: current_user.company_id)
  end
end
