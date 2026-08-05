# frozen_string_literal: true

class BreadcrumbComponent < ViewComponent::Base
  # @param items [Array<Hash>] パンくずアイテム [{label:, url:}, ...]
  #   最後のアイテムは url: nil として current page 扱い
  def initialize(items:)
    raise ArgumentError, "items は1件以上必要です" if items.blank?

    @items = items
  end

  # ラベルが200文字を超える場合に truncate するヘルパー
  def truncated_label(label)
    label.length > 200 ? label.truncate(200) : label
  end

  # ラベルが200文字を超える場合のみ title 属性用のフルテキストを返す
  def title_for(label)
    label.length > 200 ? label : nil
  end

  # 最終アイテムかどうかを判定
  def last_item?(item)
    item == @items.last
  end
end
