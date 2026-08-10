# frozen_string_literal: true

# Lograge — 1リクエスト1行の構造化ログ
# 本番環境でのログ集約・検索を容易にする。

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # ActionController の標準ログを抑制し、lograge に統一
  config.lograge.keep_original_rails_log = false

  # カスタムペイロード: request_id, user_id, remote_ip を追加
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      remote_ip: controller.request.remote_ip,
      user_id: controller.respond_to?(:current_user, true) && controller.send(:current_user)&.id
    }
  end

  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      params: event.payload[:params]&.except(*exceptions),
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception_object]&.message&.truncate(200)
    }.compact
  end
end
