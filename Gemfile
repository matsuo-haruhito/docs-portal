source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.6", ">= 1.6.3"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"
gem "csv"
gem "vite_rails"

gem "pundit"
gem "slim", "~> 5.2", ">= 5.2.1"
gem "rparam", git: "https://github.com/kmdtmyk/rparam", ref: "3a4e94706999ff794b15aaebba0ee4eb25be38d3"
gem "rtypes", git: "https://github.com/kmdtmyk/rtypes", ref: "b4a177a933261019825a3a5bfd727ad8e493ae45"
gem "tree_view", git: "https://github.com/matsuo-haruhito/tree_view-rails.git"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "factory_bot_rails", "~> 6.5", ">= 6.5.1"
  gem "rspec-rails", "~> 8.0", ">= 8.0.2"
  gem "selenium-webdriver"
end
