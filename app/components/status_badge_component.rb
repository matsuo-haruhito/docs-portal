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
    "pending" => "status-badge--draft",
    "published" => "status-badge--published",
    "active" => "status-badge--published",
    "success" => "status-badge--published",
    "completed" => "status-badge--published",
    "archived" => "status-badge--archived",
    "inactive" => "status-badge--inactive",
    "disabled" => "status-badge--inactive",
    "running" => "status-badge--running",
    "syncing" => "status-badge--running",
    "failed" => "status-badge--failed",
    "error" => "status-badge--failed",
    "warning" => "status-badge--warning"
  }.freeze

  def status_class
    STATUS_CLASSES.fetch(@status, "status-badge--unknown")
  end

  attr_reader :status, :label, :tooltip, :tooltip_id
end
