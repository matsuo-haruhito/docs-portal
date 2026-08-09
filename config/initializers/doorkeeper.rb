# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record
  base_controller "OauthController"

  resource_owner_authenticator do
    current_user || begin
      session[:oauth_return_to] = request.fullpath
      redirect_to Rails.application.routes.url_helpers.new_session_path
    end
  end

  admin_authenticator do
    current_user if current_user&.admin?
  end

  access_token_expires_in 1.hour
  authorization_code_expires_in 10.minutes
  use_refresh_token
  force_pkce

  default_scopes :"documents:read"
  optional_scopes :"documents:write", :"documents:publish"
  enforce_configured_scopes

  grant_flows %w[authorization_code]
  access_token_methods :from_bearer_authorization
  allow_blank_redirect_uri false

  force_ssl_in_redirect_uri do |uri|
    !%w[localhost 127.0.0.1 [::1]].include?(uri.host)
  end

  hash_token_secrets
  hash_application_secrets
end
