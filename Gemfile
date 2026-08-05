# frozen_string_literal: true

source "https://rubygems.org"

gem "bcrypt", "~> 3.1.7"
gem "bootsnap", require: false
gem "crass", ">= 1.0.7"
gem "csv"
gem "diff-lcs", "~> 1.6"
gem "image_processing", "~> 2.0"
gem "importmap-rails"
gem "kamal", require: false
gem "msgpack", ">= 1.8.2"
gem "pg", "~> 1.6", ">= 1.6.3"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.1.3"
gem "ruby-vips", "~> 2.0"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "stimulus-rails"
gem "thruster", require: false
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "vite_rails"

gem "caxlsx"                       # xlsx エクスポート
gem "chartkick"                    # グラフ表示（Chart.js ラッパー）
gem "enum_help"                    # enum値のI18n対応ヘルパー
gem "gretel"                       # パンくずリスト
gem "lograge"                      # 本番ログ整形（1リクエスト1行JSON寄り）
gem "marginalia"                   # SQLコメント付与（controller/action追跡）
gem "pagy"                         # ページネーション
gem "pundit"
gem "rack-attack"                  # APIレート制限・ブルートフォース防止
gem "rails_fields_kit", git: "https://github.com/matsuo-haruhito/rails_fields_kit.git",
                        ref: "0c29bb935a1df3e61add860a966a2fc7ea586b1a"
gem "rails_table_preferences", git: "https://github.com/matsuo-haruhito/rails_table_preferences.git",
                               ref: "b3f1a9d6eb46aefe568c637396fab63151aef322"
gem "rparam", git: "https://github.com/kmdtmyk/rparam", ref: "3a4e94706999ff794b15aaebba0ee4eb25be38d3"
gem "rtypes", git: "https://github.com/kmdtmyk/rtypes", ref: "b4a177a933261019825a3a5bfd727ad8e493ae45"
gem "slim", "~> 5.2", ">= 5.2.1"
gem "strong_migrations"            # 危険なDDL（ロック長期化等）を事前検知
gem "tree_view", git: "https://github.com/matsuo-haruhito/tree_view-rails.git",
                 ref: "e129cb3ce2835a483e87fc71a50cc9fee07e3da5"
gem "view_component"               # UIコンポーネント化

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "database_consistency", require: false # DB制約とvalidationの整合確認
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "prosopite"                  # N+1 自動検知
  gem "rubocop-rails-omakase", require: false
  gem "shoulda-matchers"           # バリデーション・アソシエーションマッチャー
  gem "slim_lint", require: false  # Slimテンプレート構文チェック
end

group :development do
  gem "annotate", require: false   # モデルファイルにスキーマコメント自動付与
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "factory_bot_rails", "~> 6.5", ">= 6.5.1"
  gem "rspec-rails", "~> 8.0", ">= 8.0.2"
  gem "selenium-webdriver"
end
