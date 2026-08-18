# frozen_string_literal: true

require "digest"

module ProjectsHelper
  def project_document_detail_tree_render_state(project:, documents:, expansion_mode: nil, expanded_keys: nil)
    path_tree_builder = project_document_detail_path_tree_builder(project:, documents:)
    tree = path_tree_builder.tree
    tree_instance_key = project_document_detail_tree_instance_key(project)
    expanded_keys ||= project_document_detail_tree_initial_expanded_keys(project:, tree:, expansion_mode:)

    ui_config = TreeView::UiConfigBuilder.new(
      context: self,
      node_prefix: "project_document_detail_tree",
      key_resolver: ->(item_or_id) { project_document_detail_tree_node_key(item_or_id) }
    ).build_turbo(
      hide_descendants_path_builder: ->(item, _depth, _scope) { project_document_detail_tree_toggle_path(project, item, "hide") },
      show_descendants_path_builder: ->(item, _depth, _scope) { project_document_detail_tree_toggle_path(project, item, "show") },
      toggle_all_path_builder: ->(state) { project_document_detail_tree_toggle_all_path(project, state) }
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

  def project_document_detail_tree_expanded_keys(tree)
    tree.root_items.flat_map { |node| project_document_detail_tree_folder_keys(tree, node) }
  end

  def project_document_detail_tree_node_key(item_or_id)
    case item_or_id
    when TreeView::PathTreeBuilder::FolderNode
      item_or_id.key
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
      { html: item.folder_node? ? tree_icon("folder_closed", title: "フォルダを開く") : tree_toggle_leaf_icon(item_or_record(item)), class: "tree-toggle__icon--open", title: "開く" }
    when :expanded
      { html: item.folder_node? ? tree_icon("folder_open", title: "フォルダを閉じる") : tree_toggle_leaf_icon(item_or_record(item)), class: "tree-toggle__icon--close", title: "閉じる" }
    else
      { html: children.empty? && item.record_node? ? tree_toggle_leaf_icon(item_or_record(item)) : "・", class: "tree-toggle__icon--leaf", title: item.record_node? ? tree_toggle_leaf_icon_title(item_or_record(item)) : "子項目はありません" }
    end
  end

  def project_document_detail_tree_row_class(item)
    classes = ["project-document-detail-tree__row"]
    classes << "project-document-detail-tree__folder-row" if item.folder_node?
    classes << "project-document-detail-tree__document-row" if item.record_node?
    classes
  end

  private

  def project_document_detail_path_tree_builder(project:, documents:)
    TreeView::PathTreeBuilder.new(
      records: documents,
      path_resolver: ->(document) { document_tree_source_path_for_tree(document) },
      label_resolver: ->(document) { tree_item_label(document) },
      id_resolver: ->(document) { "document_#{document.id}" },
      folder_key_resolver: ->(segments) {
        path = segments.join("/")
        "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
      },
      sort: { folders_first: true }
    )
  end

  # source_directory をフルパスとして PathTreeBuilder に渡す
  def document_tree_source_path_for_tree(document)
    directory = document_tree_source_directory(document).to_s
    return document.title if directory.blank?

    "#{directory}/#{document.title}"
  end

  def project_document_detail_tree_initial_expanded_keys(project:, tree:, expansion_mode: nil)
    return [] if expansion_mode == "collapse"
    return project_document_detail_tree_expanded_keys(tree) if expansion_mode == "expand"

    persisted_state = current_user.respond_to?(:tree_view_state_for) ? current_user.tree_view_state_for(project_document_detail_tree_instance_key(project)) : nil
    return Array(persisted_state.expanded_keys) if persisted_state

    project_document_detail_tree_expanded_keys(tree)
  end

  def project_document_detail_tree_toggle_path(project, item, action)
    return unless item.folder_node?

    document_detail_tree_project_path(
      project,
      tree_action: action,
      source_path: item.path,
      format: :turbo_stream
    )
  end

  def project_document_detail_tree_toggle_all_path(project, state)
    tree_action = state.to_sym == :expanded ? "expand" : "collapse"

    document_detail_tree_project_path(project, tree_action:, format: :turbo_stream)
  end

  def project_document_detail_tree_folder_keys(tree, node)
    return [] unless node.folder_node?

    [node.key] + tree.children_for(node).flat_map { |child| project_document_detail_tree_folder_keys(tree, child) }
  end

  # PathTreeBuilder の RecordNode から元のレコードを取り出す
  def item_or_record(item)
    item.respond_to?(:record) ? item.record : item
  end
end
