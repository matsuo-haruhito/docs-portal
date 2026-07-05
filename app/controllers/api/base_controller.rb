class Api::BaseController < ActionController::API
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ApplicationError::BadRequest, with: :render_bad_request
  rescue_from ApplicationError::Forbidden, with: :render_forbidden
  rescue_from ApplicationError::Unauthorized, with: :render_unauthorized

  private

  def bearer_token
    request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
  end

  def authenticate_bearer_token!(env_key)
    expected = ENV.fetch(env_key, "")
    token = bearer_token

    unless expected.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
      raise ApplicationError::Unauthorized
    end
  end

  def read_only_maintenance?
    ActiveModel::Type::Boolean.new.cast(ENV["READ_ONLY_MAINTENANCE"])
  end

  def render_read_only_maintenance_response
    render json: { error: "READ_ONLY_MAINTENANCE is enabled; internal upload apply requests are paused." }, status: :service_unavailable
  end

  def render_bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end

  def render_not_found(error)
    render json: { error: error.message }, status: :not_found
  end

  def render_forbidden(error)
    render json: { error: error.message.presence || "Forbidden" }, status: :forbidden
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
