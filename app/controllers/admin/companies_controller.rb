class Admin::CompaniesController < Admin::BaseController
  before_action :set_company, only: %i[edit update destroy]
  before_action :require_company_master_admin!

  def index
    @companies = Company.order(:code)
    @company = Company.new(active: true)
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to admin_companies_path, notice: "会社を登録しました。"
    else
      @companies = Company.order(:code)
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
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:code, :name, :active)
  end

  def require_company_master_admin!
    raise ApplicationError::Forbidden unless company_master_admin?
  end
end
