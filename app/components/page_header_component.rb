# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  renders_one :breadcrumbs  # BreadcrumbComponent を受ける slot
  renders_many :actions     # action links/buttons

  # @param title [String] 画面タイトル（必須）
  # @param subtitle [String, nil] サブタイトル（任意）
  def initialize(title:, subtitle: nil)
    raise ArgumentError, "title は必須です" if title.blank?

    @title = title
    @subtitle = subtitle
  end
end
