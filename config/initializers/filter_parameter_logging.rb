Rails.application.config.filter_parameters += [
  :password,
  :password_confirmation,
  :authorization,
  :token,
  :secret,
  :docs_portal_sync_token
]
