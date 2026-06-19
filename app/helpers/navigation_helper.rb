module NavigationHelper
  def nav_current_child_label(*items)
    items.find { |_label, path| nav_current_child_path?(path) }&.first
  end

  private

  def nav_current_child_path?(path)
    candidate_path = path.to_s.split("?").first
    return false if candidate_path.blank?

    current_path = request.path
    current_path == candidate_path || (candidate_path != "/" && current_path.start_with?("#{candidate_path}/"))
  end
end
