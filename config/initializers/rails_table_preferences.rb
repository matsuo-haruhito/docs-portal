# frozen_string_literal: true

RailsTablePreferences.configure do |config|
  config.table_name = "table_preferences"
  config.owner_model = :users

  # docs-portal uses explicit Japanese labels in table definitions, but keeps
  # locale and humanize fallbacks useful while we gradually migrate admin tables.
  config.label_resolution = %i[
    label
    i18n_key
    column_comment
    activerecord_attribute_i18n
    activemodel_attribute_i18n
    attribute_i18n
    humanize
  ]
  config.unresolved_label_behavior = :humanize

  config.parent_controller_class_name = "ApplicationController"
  config.current_user_method = :current_user
  config.mount_path = "/rails_table_preferences"
  config.editor_partial = "rails_table_preferences/editor"
end
