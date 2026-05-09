module TreeViewStateOwner
  extend ActiveSupport::Concern

  included do
    has_many :tree_view_states, as: :owner, dependent: :destroy
  end

  def tree_view_state_for(tree_instance_key)
    TreeView::StateStore.new(model: TreeViewState).find(
      owner: self,
      tree_instance_key:
    )
  end

  def save_tree_view_state!(tree_instance_key, expanded_keys:)
    TreeView::StateStore.new(model: TreeViewState).save!(
      owner: self,
      tree_instance_key:,
      expanded_keys:
    )
  end
end
