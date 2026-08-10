require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # リバースプロキシ (ALB / Cloud Run 等) で TLS 終端する前提。
  # Rails 側は X-Forwarded-Proto を信頼し、HTTP リクエストを HTTPS へリダイレクトする。
  config.assume_ssl = true
  config.force_ssl = true

  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # メーラーのリンク生成に使うホスト。ENV 必須。
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST"), protocol: "https" }

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
  config.active_job.queue_adapter = :solid_queue
end
