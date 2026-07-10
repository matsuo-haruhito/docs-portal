source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.6", ">= 1.6.3"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "websocket-driver", ">= 0.8.2"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "crass", ">= 1.0.7"
gem "msgpack", ">= 1.8.2"
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 2.0"
gem "csv"
gem "diff-lcs", "~> 1.6"
gem "vite_rails"

gem "pundit"
gem "slim", "~> 5.2", ">= 5.2.1"
gem "rparam", git: "https://github.com/kmdtmyk/rparam", ref: "3a4e94706999ff794b15aaebba0ee4eb25be38d3"
gem "rtypes", git: "https://github.com/kmdtmyk/rtypes", ref: "b4a177a933261019825a3a5bfd727ad8e493ae45"
gem "tree_view", git: "https://github.com/matsuo-haruhito/tree_view-rails.git", ref: "e129cb3ce2835a483e87fc71a50cc9fee07e3da5"
gem "rails_table_preferences", git: "https://github.com/matsuo-haruhito/rails_table_preferences.git", ref: "b3f1a9d6eb46aefe568c637396fab63151aef322"
gem "rails_fields_kit", git: "https://github.com/matsuo-haruhito/rails_fields_kit.git", ref: "0c29bb935a1df3e61add860a966a2fc7ea586b1a"

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
