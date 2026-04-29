class ApplicationController < ActionController::Base
  include Pundit::Authorization

  helper_method :current_user, :logged_in?, :admin_user?, :company_master_admin?

  rescue_from Pundit::NotAuthorizedError, with: :raise_forbidden
  rescue_from ApplicationError::Forbidden, with: :render_forbidden
  before_action :authenticate_user!
  before_action { Current.user = current_user }
  after_action { Current.reset }

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    reset_session_if_stale!
    return if logged_in?

    redirect_to new_session_path, alert: "ログインしてください。"
  end

  def admin_user?
    current_user&.admin?
  end

  def company_master_admin?
    current_user&.can_manage_company_master?
  end

  def raise_forbidden
    raise ApplicationError::Forbidden
  end

  def render_forbidden
    render plain: "Forbidden", status: :forbidden
  end

  def reset_session_if_stale!
    return if session[:user_id].blank?
    return if current_user.present?

    reset_session
  end
end
