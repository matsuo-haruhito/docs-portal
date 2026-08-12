# frozen_string_literal: true

class GuidanceDisclosureComponent < ViewComponent::Base
  def initialize(title: "補足を確認", icon: "bi-info-circle")
    raise ArgumentError, "title は必須です" if title.blank?

    @title = title
    @icon = icon
  end
end
