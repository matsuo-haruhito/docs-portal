module NavbarHelper
  def nav_dropdown_active?(*paths)
    paths.any? { |path| current_nav_path?(path) }
  end

  def active_nav_link_to(label, path, active: current_nav_path?(path))
    options = { class: ["nav-dropdown__item", ("is-active" if active)].compact }
    options[:aria] = { current: "page" } if active

    link_to(path, options) do
      active ? active_nav_label(label) : label
    end
  end

  def active_nav_label(label)
    safe_join([label, tag.span("現在", class: "badge")], " ")
  end

  def current_nav_path?(path)
    request.path == path
  end
end
