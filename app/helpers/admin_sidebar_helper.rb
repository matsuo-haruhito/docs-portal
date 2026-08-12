# frozen_string_literal: true

module AdminSidebarHelper
  def admin_sidebar_link(label, path, icon: nil)
    active = current_nav_path?(path)
    css_class = "admin-sidebar__link#{' is-active' if active}"
    options = { class: css_class }
    options[:aria] = { current: "page" } if active

    link_to path, **options do
      icon_html = icon ? tag.i(class: "bi #{icon}", aria: { hidden: true }) : "".html_safe
      icon_html + tag.span(label, class: "admin-sidebar__link-label")
    end
  end

  private

  def current_nav_path?(path)
    candidate = path.split("?").first
    current = request.path

    return true if current == candidate
    return true if current.start_with?("#{candidate}/") && candidate != "/"

    false
  end
end
