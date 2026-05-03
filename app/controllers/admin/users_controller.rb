class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[edit update destroy]
  before_action :load_companies, only: %i[index create edit update]

  def index
    @users = user_scope.includes(:company).order(:email_address)
    @user = User.new(active: true, user_type: default_user_type_for_form, company: default_company_for_form)
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_users_path, notice: "ユーザーを登録しました。"
    else
      @users = user_scope.includes(:company).order(:email_address)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "ユーザーを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    redirect_to admin_users_path, notice: "ユーザーを削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_users_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to admin_users_path, alert: "関連データがあるため削除できません。"
  end

  private

  def set_user
    @user = user_scope.find(params[:id])
  end

  def load_companies
    @companies = company_master_admin? ? Company.where(id: current_user.company_id) : Company.order(:code)
  end

  def user_params
    permitted = params.require(:user).permit(
      :name, :email_address, :user_type, :company_id, :active, :password, :password_confirmation
    )
    if company_master_admin?
      permitted[:company_id] = current_user.company_id
      permitted[:user_type] = User.user_types.fetch("external")
    elsif permitted[:company_id].blank?
      permitted[:company_id] = nil
    end
    permitted = permitted.except(:password, :password_confirmation) if permitted[:password].blank?
    permitted
  end

  def user_scope
    return User.all if admin_user?

    User.where(company_id: current_user.company_id)
  end

  def default_company_for_form
    company_master_admin? ? current_user.company : nil
  end

  def default_user_type_for_form
    company_master_admin? ? :external : :internal
  end
end
