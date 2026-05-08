module DocumentFilesHelper
  def document_file_tree_render_state(files:, row_partial:, node_prefix:)
    nodes = DocumentFilePresentation::TreeBuilder.new(files: files).call
    return if nodes.empty?

    tree = TreeView::Tree.new(records: nodes, parent_id_method: :parent_node_id)
    ui_config = TreeView::UiConfigBuilder.new(context: self, node_prefix:).build_static

    TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial:,
      ui_config:
    )
  end
end
