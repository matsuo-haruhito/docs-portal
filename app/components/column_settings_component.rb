# frozen_string_literal: true

class ColumnSettingsComponent < ViewComponent::Base
  def initialize(table_key:, settings:, columns:, title:, description: nil)
    raise ArgumentError, "table_key は必須です" if table_key.blank?
    raise ArgumentError, "title は必須です" if title.blank?

    @table_key = table_key
    @settings = settings
    @columns = columns
    @title = title
    @description = description.presence
    @dialog_id = "column-settings-#{SecureRandom.hex(4)}"
    @title_id = "#{@dialog_id}-title"
  end
end
