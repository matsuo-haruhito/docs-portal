class ApplicationController < ActionController::Base
  layout "application"

  helper_method :current_user, :logged_in?, :admin_user?, :company_master_admin?

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ApplicationError::BadRequest, with: :render_bad_request
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

  def render_forbidden(_error = nil)
    render_error_page(
      status: :forbidden,
      title: "アクセスできません",
      message: "このページまたはファイルへアクセスする権限がありません。"
    )
  end

  def render_not_found(_error = nil)
    render_error_page(
      status: :not_found,
      title: "見つかりません",
      message: "指定されたページまたはファイルは見つかりませんでした。"
    )
  end

  def render_bad_request(_error = nil)
    render_error_page(
      status: :bad_request,
      title: "リクエストを処理できません",
      message: "入力内容または操作条件を確認して、もう一度お試しください。"
    )
  end

  def render_error_page(status:, title:, message:)
    @error_title = title
    @error_message = message
    @error_status = Rack::Utils.status_code(status)
    render "shared/error_page", formats: :html, status:
  end

  def reset_session_if_stale!
    return if session[:user_id].blank?
    return if current_user.present?

    reset_session
  end
end
