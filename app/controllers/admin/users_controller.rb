class Admin::UsersController < Admin::BaseController
  COMPANY_SEARCH_QUERY_MAX_LENGTH = 100
  COMPANY_SEARCH_LIMIT = 20

  before_action :set_user, only: %i[edit update destroy]
  before_action :prepare_form_context, only: %i[index create edit update]
  before_action :ensure_admin_master_maintenance_writable!, only: %i[create update destroy]

  helper_method :user_return_to_path

  def index
    @users = filtered_users
    @user = User.new(active: true, user_type: default_user_type_for_form, company: default_company_for_form)
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_users_path, notice: "ユーザーを登録しました。"
    else
      @users = filtered_users
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to user_return_to_path, notice: "ユーザーを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    redirect_to user_return_to_path, notice: "ユーザーを削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to user_return_to_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to user_return_to_path, alert: "関連データがあるため削除できません。"
  end

  def company_search
    render json: { options: user_company_options(searchable_user_companies) }
  end

  def selected_company
    company = selected_user_company

    render json: { option: company ? user_company_option(company) : nil }
  end

  private

  def filtered_users
    @user_filter_params = user_filter_params
    @users_total_count = user_scope.count

    filtered_scope = user_scope.includes(:company).then { |scope| apply_user_filters(scope) }
    @users_filtered_count = filtered_scope.count
    users, @users_pagination = paginate_admin_list(filtered_scope.order(:email_address), @users_filtered_count)
    @user_page_params = user_page_params

    users
  end

  def apply_user_filters(scope)
    scope = filter_users_by_keyword(scope)
    filter_users_by_active(scope)
  end

  def filter_users_by_keyword(scope)
    keyword = @user_filter_params["q"].to_s.strip
    return scope if keyword.blank?

    pattern = "%#{User.sanitize_sql_like(keyword.downcase)}%"
    scope.where(
      "LOWER(users.name) LIKE :keyword OR LOWER(users.email_address) LIKE :keyword",
      keyword: pattern
    )
  end

  def filter_users_by_active(scope)
    case @user_filter_params["active"]
    when "true"
      scope.where(active: true)
    when "false"
      scope.where(active: false)
    else
      scope
    end
  end

  def user_filter_params
    params.permit(:q, :active).to_h
  end

  def user_page_params
    page_params = @user_filter_params.dup
    page_params["per_page"] = @users_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def set_user
    @user = user_scope.find_by!(public_id: params[:public_id])
  end

  def user_return_to_path
    safe_return_to_path(admin_users_path)
  end

  def prepare_form_context
    @company_admin_user_form = company_master_admin_user?
    @fixed_company_for_form = current_user.company if @company_admin_user_form
  end

  def user_params
    permitted = params.require(:user).permit(
      :name, :email_address, :user_type, :company_id, :active, :password, :password_confirmation
    )
    if company_master_admin_user?
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

  def ensure_admin_master_maintenance_writable!
    return unless read_only_maintenance_mode?

    redirect_to user_return_to_path, alert: admin_master_maintenance_message
  end

  def company_master_admin_user?
    !admin_user? && company_master_admin?
  end

  def default_company_for_form
    company_master_admin_user? ? current_user.company : nil
  end

  def default_user_type_for_form
    company_master_admin_user? ? :external : :internal
  end

  def searchable_user_companies
    scope = user_company_scope.order(:domain, :id)
    query = normalized_company_search_query(params[:q])
    return scope.limit(COMPANY_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Company.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(companies.domain) LIKE :pattern OR LOWER(companies.name) LIKE :pattern",
      pattern:
    ).limit(COMPANY_SEARCH_LIMIT)
  end

  def selected_user_company
    return if params[:id].blank?

    user_company_scope.find_by(id: params[:id])
  end

  def user_company_scope
    return Company.where(id: current_user.company_id) if company_master_admin_user?

    Company.all
  end

  def normalized_company_search_query(value)
    value.to_s.strip.first(COMPANY_SEARCH_QUERY_MAX_LENGTH)
  end

  def user_company_options(companies)
    companies.map { user_company_option(_1) }
  end

  def user_company_option(company)
    { value: company.id, text: helpers.admin_user_company_label(company) }
  end
end
