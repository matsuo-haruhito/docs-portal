# frozen_string_literal: true

class HelpTooltipComponent < ViewComponent::Base
  # @param description [String] 操作ガイドテキスト（必須、最大200文字）
  def initialize(description:)
    raise ArgumentError, "description は必須です" if description.blank?

    @description = description.truncate(200)
    @tooltip_id = "tooltip-#{SecureRandom.hex(4)}"
  end

  attr_reader :description, :tooltip_id
end
