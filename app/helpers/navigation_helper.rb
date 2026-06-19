module NavigationHelper
  def nav_current_child_label(*items)
    exact_match = items.find { |_label, path| nav_current_child_exact_path?(path) }
    return exact_match.first if exact_match

    items.find { |_label, path| nav_current_child_nested_path?(path) }&.first
  end

  private

  def nav_current_child_exact_path?(path)
    request.path == nav_candidate_path(path)
  end

  def nav_current_child_nested_path?(path)
    candidate_path = nav_candidate_path(path)
    return false if candidate_path.blank? || candidate_path == "/"

    request.path.start_with?("#{candidate_path}/")
  end

  def nav_candidate_path(path)
    path.to_s.split("?").first
  end
end
