# frozen_string_literal: true

class FilterToolbarComponent < ViewComponent::Base
  class FieldComponent < ViewComponent::Base
    SIZES = %i[default query remote enum date short wide].freeze

    def initialize(size: :default)
      @size = size.to_sym
      raise ArgumentError, "未対応のフィールド幅です: #{@size}" unless SIZES.include?(@size)
    end

    def call
      content_tag(
        :div,
        content,
        class: class_names("filter-toolbar__field", "filter-toolbar__field--#{@size}" => @size != :default)
      )
    end
  end

  renders_many :fields, FieldComponent
  renders_one :details
  renders_many :actions
  renders_many :active_filters

  def initialize(label:)
    raise ArgumentError, "label は必須です" if label.blank?

    @label = label
  end
end
