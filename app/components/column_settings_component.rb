# frozen_string_literal: true

class ColumnSettingsComponent < ViewComponent::Base
  def initialize(table_key:, settings:, columns:, title:)
    raise ArgumentError, "table_key は必須です" if table_key.blank?
    raise ArgumentError, "title は必須です" if title.blank?

    @table_key = table_key
    @settings = settings
    @columns = columns
    @title = title
  end
end
