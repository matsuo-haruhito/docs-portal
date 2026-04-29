require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module DocsPortal
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "Asia/Tokyo"
    config.i18n.available_locales = %i[ja en]
    config.i18n.default_locale = :ja
  end
end
