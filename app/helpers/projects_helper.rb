require "digest"

module ProjectsHelper
  ProjectDocumentDetailTreeFolderNode = Data.define(:project, :path, :label, :children)

  def project_document_detail_tree_render_state(project:, documents:, expansion_mode: nil, expanded_keys: nil)
    nodes = project_document_detail_tree_nodes(project:, documents:)
    tree_instance_key = project_document_detail_tree_instance_key(project)
    expanded_keys ||= project_document_detail_tree_initial_expanded_keys(project:, nodes:, expansion_mode:)

    adapter = TreeView::GraphAdapter.new(
      roots: nodes,
      children_resolver: lambda do |node|
        node.is_a?(ProjectDocumentDetailTreeFolderNode) ? node.children : []
      end,
      node_key_resolver: ->(node) { project_document_detail_tree_node_key(node) }
    )

    tree = TreeView::Tree.new(adapter:)
    ui_config = TreeView::UiConfigBuilder.new(
      context: self,
      node_prefix: "project_document_detail_tree",
      key_resolver: ->(item_or_id) { project_document_detail_tree_node_key(item_or_id) }
    ).build_turbo(
      hide_descendants_path_builder: ->(item, _depth, _scope) { project_document_detail_tree_toggle_path(item, "hide") },
      show_descendants_path_builder: ->(item, _depth, _scope) { project_document_detail_tree_toggle_path(item, "show") },
      toggle_all_path_builder: ->(state) { document_detail_tree_project_path(project, tree_action: state, format: :turbo_stream) }
    )

    TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial: "projects/document_detail_tree_columns",
      ui_config:,
      tree_instance_key:,
      initial_expansion: {
        default: :collapsed,
        expanded_keys:,
        collapsed_keys: []
      },
      toggle_icon_builder: ->(item, state, context) { project_document_detail_tree_toggle_label(item, state, context) },
      row_class_builder: ->(item) { project_document_detail_tree_row_class(item) }
    )
  end

  def project_document_detail_tree_instance_key(project)
    "documents:project_detail:#{project.id}"
  end

  def project_document_detail_tree_nodes(project:, documents:)
    root_nodes = []
    folder_nodes_by_path = {}

    documents.each do |document|
      directory = document_tree_source_directory(document).to_s
      if directory.blank?
        root_nodes << document
        next
      end

      parent_nodes = root_nodes
      path_segments = []
      directory.split("/").reject(&:blank?).each do |segment|
        path_segments << segment
        path = path_segments.join("/")
        folder_node = folder_nodes_by_path[path]
        unless folder_node
          folder_node = ProjectDocumentDetailTreeFolderNode.new(project:, path:, label: segment, children: [])
          folder_nodes_by_path[path] = folder_node
          parent_nodes << folder_node
        end
        parent_nodes = folder_node.children
      end
      parent_nodes << document
    end

    sort_project_document_detail_tree_nodes!(root_nodes)
    root_nodes
  end

  def project_document_detail_tree_expanded_keys(nodes)
    nodes.flat_map do |node|
      if node.is_a?(ProjectDocumentDetailTreeFolderNode)
        [project_document_detail_tree_node_key(node), *project_document_detail_tree_expanded_keys(node.children)]
      else
        []
      end
    end
  end

  def project_document_detail_tree_node_key(item_or_id)
    case item_or_id
    when ProjectDocumentDetailTreeFolderNode
      "project_detail_folder_#{item_or_id.project.id}_#{Digest::SHA256.hexdigest(item_or_id.path).first(16)}"
    else
      if item_or_id.respond_to?(:id)
        "#{item_or_id.class.name.underscore}_#{item_or_id.id}"
      else
        item_or_id.to_s
      end
    end
  end

  def project_document_detail_tree_toggle_label(item, state, context)
    children = Array(context[:children])

    case state.to_sym
    when :collapsed
      { html: item.is_a?(ProjectDocumentDetailTreeFolderNode) ? tree_icon("folder_closed", title: "フォルダを開く") : tree_toggle_leaf_icon(item), class: "tree-toggle__icon--open", title: "開く" }
    when :expanded
      { html: item.is_a?(ProjectDocumentDetailTreeFolderNode) ? tree_icon("folder_open", title: "フォルダを閉じる") : tree_toggle_leaf_icon(item), class: "tree-toggle__icon--close", title: "閉じる" }
    else
      { html: children.empty? && item.is_a?(Document) ? tree_toggle_leaf_icon(item) : "・", class: "tree-toggle__icon--leaf", title: item.is_a?(Document) ? tree_toggle_leaf_icon_title(item) : "子項目はありません" }
    end
  end

  def project_document_detail_tree_row_class(item)
    classes = ["project-document-detail-tree__row"]
    classes << "project-document-detail-tree__folder-row" if item.is_a?(ProjectDocumentDetailTreeFolderNode)
    classes << "project-document-detail-tree__document-row" if item.is_a?(Document)
    classes
  end

  private

  def project_document_detail_tree_initial_expanded_keys(project:, nodes:, expansion_mode: nil)
    return [] if expansion_mode == "collapse"
    return project_document_detail_tree_expanded_keys(nodes) if expansion_mode == "expand"

    persisted_state = current_user.respond_to?(:tree_view_state_for) ? current_user.tree_view_state_for(project_document_detail_tree_instance_key(project)) : nil
    return Array(persisted_state.expanded_keys) if persisted_state

    project_document_detail_tree_expanded_keys(nodes)
  end

  def project_document_detail_tree_toggle_path(item, action)
    return unless item.is_a?(ProjectDocumentDetailTreeFolderNode)

    document_detail_tree_project_path(
      item.project,
      tree_action: action,
      source_path: item.path,
      format: :turbo_stream
    )
  end

  def sort_project_document_detail_tree_nodes!(nodes)
    nodes.sort_by! do |node|
      case node
      when ProjectDocumentDetailTreeFolderNode
        [0, node.label.to_s]
      when Document
        [1, tree_item_label(node).to_s]
      else
        [2, node.to_s]
      end
    end

    nodes.each do |node|
      sort_project_document_detail_tree_nodes!(node.children) if node.is_a?(ProjectDocumentDetailTreeFolderNode)
    end
  end
end
