# frozen_string_literal: true

Rails.application.routes.append do
  mount RailsTablePreferences::Engine, at: "/rails_table_preferences"
end
