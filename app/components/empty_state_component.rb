# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  renders_many :actions

  # @param heading [String] 見出し（必須）
  # @param description [String] 説明テキスト（必須）
  # @param icon [String] Bootstrap Icons クラス名（省略時: "bi-inbox"）
  def initialize(heading:, description:, icon: "bi-inbox")
    raise ArgumentError, "heading is required" if heading.blank?
    raise ArgumentError, "description is required" if description.blank?

    @heading = heading
    @description = description
    @icon = icon
  end
end
