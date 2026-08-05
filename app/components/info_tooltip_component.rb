# frozen_string_literal: true

class InfoTooltipComponent < ViewComponent::Base
  # @param label [String] 説明対象の用語（必須）
  # @param description [String] 補足説明テキスト（必須、最大200文字）
  def initialize(label:, description:)
    raise ArgumentError, "label は必須です" if label.blank?
    raise ArgumentError, "description は必須です" if description.blank?

    @label = label
    @description = description.truncate(200)
    @tooltip_id = "tooltip-#{SecureRandom.hex(4)}"
  end

  attr_reader :label, :description, :tooltip_id
end
