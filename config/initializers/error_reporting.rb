# frozen_string_literal: true

# エラー監視 — Rails 標準の ErrorReporter を活用
#
# Rails 7.1+ の `Rails.error.report` / `Rails.error.handle` で捕捉したエラーを
# 外部サービスへ送る subscriber を登録する。
#
# 現時点では構造化ログ (STDOUT JSON) へ出力し、
# Sentry / Honeybadger 等を導入する際はここに subscriber を追加する。

class ErrorLogSubscriber
  CONTEXT_KEYS = %i[request_id user_id controller action].freeze

  # Rails ErrorReporter の subscriber interface
  def report(error, handled:, severity:, context: {}, source: nil)
    payload = {
      error_class: error.class.name,
      error_message: error.message.truncate(500),
      severity: severity,
      handled: handled,
      source: source
    }.merge(serializable_context(context))

    case severity
    when :error
      Rails.logger.error("[ErrorReporter] #{payload.to_json}")
    when :warning
      Rails.logger.warn("[ErrorReporter] #{payload.to_json}")
    else
      Rails.logger.info("[ErrorReporter] #{payload.to_json}")
    end
  end

  private

  def serializable_context(context)
    context.slice(*CONTEXT_KEYS).transform_values do |value|
      case value
      when nil, true, false, Numeric, String
        value
      when Symbol
        value.to_s
      else
        value.class.name
      end
    end
  end
end

Rails.application.configure do
  # 標準の構造化ログ出力 subscriber を常に登録
  config.after_initialize do
    Rails.error.subscribe(ErrorLogSubscriber.new)
  end
end

# ------------------------------------------------------------------
# 外部サービス導入時の追加手順:
#
# 1. Gemfile に gem を追加（例: gem "sentry-ruby", gem "sentry-rails"）
# 2. 下記のように subscriber を追加登録する:
#
#   if ENV["SENTRY_DSN"].present?
#     Sentry.init do |config|
#       config.dsn = ENV["SENTRY_DSN"]
#       config.breadcrumbs_logger = [:active_support_logger, :http_logger]
#       config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
#     end
#     # Sentry は Rails ErrorReporter に自動で subscribe する
#   end
#
# 3. .env.example に SENTRY_DSN= を追加する
# ------------------------------------------------------------------
