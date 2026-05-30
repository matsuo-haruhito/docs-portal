# frozen_string_literal: true

# Rack 3.2+ deprecates the :unprocessable_entity status symbol in favor of
# :unprocessable_content. Normalize legacy matcher input before rspec-rails
# delegates to Rack::Utils.status_code so request specs stay warning-free while
# older expectations are migrated incrementally.
module HttpStatusMatcherAliases
  def have_http_status(status)
    normalized_status = status == :unprocessable_entity ? :unprocessable_content : status

    super(normalized_status)
  end
end

RSpec.configure do |config|
  config.include HttpStatusMatcherAliases
end
