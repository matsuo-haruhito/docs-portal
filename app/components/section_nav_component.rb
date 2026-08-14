# frozen_string_literal: true

class SectionNavComponent < ViewComponent::Base
  MAX_TABS = 10

  # @param sections [Array<Hash>] [{id:, label:}, ...] 最大10件
  # @param aria_label [String] ナビゲーションの用途を示すラベル
  def initialize(sections:, aria_label: "文書詳細ナビゲーション")
    @sections = Array(sections).first(MAX_TABS)
    @aria_label = aria_label
  end

  # セクションが0件の場合は描画しない
  def render?
    @sections.any?
  end

  # 最初のタブかどうかを判定（aria-selected 用）
  def first_section?(section)
    section == @sections.first
  end
end
