class DocumentCommentWorkspaceTab
  TABS = %w[all qa review unresolved].freeze
  DEFAULT_TAB = "all"

  attr_reader :value

  def initialize(user:, tab:)
    requested_tab = tab.to_s
    @value = allowed_tab?(user, requested_tab) ? requested_tab : DEFAULT_TAB
  end

  private

  def allowed_tab?(user, tab)
    return false unless TABS.include?(tab)
    return user.internal? if tab == "review"

    true
  end
end
