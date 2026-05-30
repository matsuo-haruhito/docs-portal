module HeadlessChromeDriverHelper
  CHROME_ARGUMENTS = %w[
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
  ].freeze

  def driven_by_headless_chrome(screen_size: [1400, 1400])
    driven_by(:selenium, using: :headless_chrome, screen_size:) do |options|
      CHROME_ARGUMENTS.each { |argument| options.add_argument(argument) }
    end
  end
end

RSpec.configure do |config|
  config.include HeadlessChromeDriverHelper, type: :system
end
