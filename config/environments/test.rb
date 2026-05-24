Rails.application.configure do
  config.enable_reloading = false
  # Rails 8.1 currently freezes autoload path arrays before this app's internal engines finish
  # their CI-time eager loading work, so keep test boot lazy until that initialization path is fixed.
  config.eager_load = false
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }
  config.consider_all_requests_local = true
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_storage.service = :test
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }
  config.active_job.queue_adapter = :test
  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true
end
