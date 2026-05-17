# frozen_string_literal: true

RailsFieldsKit.configure do |config|
  config.controller_name = "rails-fields-kit--tom-select"

  config.default_query_param = "q"
  config.default_selected_param = "id"
  config.default_selected_multiple_param = "ids"
  config.default_create_param = "text"

  config.default_value_field = "value"
  config.default_label_field = "text"
  config.default_search_field = "text"

  config.default_min_length = 0
  config.default_max_options = nil
  config.default_preload = nil

  config.default_open_on_focus = nil
  config.default_close_after_select = nil
  config.default_hide_selected = nil
  config.default_persist = nil

  config.default_no_results_text = "該当する候補がありません"
  config.default_loading_text = "検索しています..."
  config.default_create_text = "追加"

  config.default_option_description_field = nil
  config.default_option_badge_field = nil
  config.default_plugins = []

  config.wrapper_class = "rfk-field"
  config.label_class = "rfk-label"
  config.hint_class = "rfk-hint"
  config.error_class = "rfk-error"
  config.field_error_class = "rfk-field--error"
  config.control_class = "rfk-control"
  config.prefix_class = "rfk-prefix"
  config.suffix_class = "rfk-suffix"
end
