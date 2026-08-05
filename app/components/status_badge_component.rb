# frozen_string_literal: true

class StatusBadgeComponent < ViewComponent::Base
  # @param status [String] ステータスキー（visual tone class に変換）
  # @param label [String] 表示テキスト
  # @param tooltip [String, nil] ツールチップテキスト（任意）
  def initialize(status:, label:, tooltip: nil)
    raise ArgumentError, "status は必須です" if status.blank?
    raise ArgumentError, "label は必須です" if label.blank?

    @status = status
    @label = label
    @tooltip = tooltip
    @tooltip_id = "badge-tooltip-#{SecureRandom.hex(4)}" if tooltip.present?
  end

  # status → CSS modifier class のマッピング
  STATUS_CLASSES = {
    "draft" => "status-badge--draft",
    "published" => "status-badge--published",
    "archived" => "status-badge--archived"
  }.freeze

  def status_class
    STATUS_CLASSES.fetch(@status, "status-badge--unknown")
  end

  attr_reader :status, :label, :tooltip, :tooltip_id
end
