class SessionsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :redirect_if_logged_in!, only: %i[new create]

  def new
  end

  def create
    user = User.find_by(email_address: session_params[:email_address]&.downcase)

    if user&.authenticate(session_params[:password]) && user.active?
      reset_session
      session[:user_id] = user.id
      user.update_column(:last_login_at, Time.current)
      redirect_to root_path, notice: "ログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "ログアウトしました。"
  end

  private

  def session_params
    params.require(:session).permit(:email_address, :password)
  end

  def redirect_if_logged_in!
    reset_session_if_stale!
    redirect_to root_path if logged_in?
  end
end
