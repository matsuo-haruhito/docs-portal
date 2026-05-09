class TreeViewStatesController < BaseController
  DOCUMENT_TREE_KEYS = [DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY].freeze

  def update
    tree_instance_key = params.require(:tree_instance_key).to_s
    head :not_found and return unless DOCUMENT_TREE_KEYS.include?(tree_instance_key)

    persisted_state = current_user.save_tree_view_state!(
      tree_instance_key,
      expanded_keys: Array(params[:expanded_keys]).map(&:to_s).compact_blank
    )

    render json: {
      tree_instance_key: persisted_state.tree_instance_key,
      expanded_keys: persisted_state.expanded_keys
    }
  end
end
