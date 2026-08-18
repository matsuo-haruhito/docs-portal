module DocumentFilesHelper
  def document_file_tree_render_state(files:, row_partial:, node_prefix:)
    tree_builder = DocumentFilePresentation::TreeBuilder.new(files: files)
    nodes = tree_builder.call
    return if nodes.empty?

    tree = tree_builder.tree
    ui_config = TreeView::UiConfigBuilder.new(context: self, node_prefix:).build_static

    TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial:,
      ui_config:
    )
  end

  def document_file_viewer_plan(file)
    DocumentFileViewerPlan.new(file:, user: current_user).call
  end
end
