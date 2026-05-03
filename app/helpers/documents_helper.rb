module DocumentsHelper
  def document_tree_render_state(projects:)
    adapter = TreeView::GraphAdapter.new(
      roots: projects,
      children_resolver: lambda do |node|
        if node.is_a?(Project)
          node.documents.accessible_to(current_user).order(:title)
        else
          []
        end
      end
    )

    tree = TreeView::Tree.new(adapter:)
    ui_config = TreeView::UiConfig.new(
      node_dom_id_builder: ->(item_or_id) { "document_tree_#{node_key(item_or_id)}" },
      button_dom_id_builder: ->(item_or_id) { "document_tree_button_#{node_key(item_or_id)}" },
      show_button_dom_id_builder: ->(item_or_id) { "document_tree_show_button_#{node_key(item_or_id)}" },
      hide_descendants_path_builder: ->(_item, _depth, _scope) { "#" },
      show_descendants_path_builder: ->(_item, _depth, _scope) { "#" },
      toggle_all_path_builder: ->(_state) { "#" }
    )

    TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial: "documents/tree_columns",
      ui_config:,
      initial_state: :expanded
    )
  end

  def tree_item_path(item)
    case item
    when Project
      project_documents_path(item)
    when Document
      project_document_path(item.project, item.slug)
    end
  end

  def tree_item_label(item)
    case item
    when Project
      "#{item.code} #{item.name}"
    when Document
      item.title
    else
      item.to_s
    end
  end

  def tree_item_css_class(item)
    classes = []
    classes << "current-node" if item == @project || item == @document
    classes.join(" ")
  end

  private

  def node_key(item_or_id)
    if item_or_id.respond_to?(:id)
      "#{item_or_id.class.name.underscore}_#{item_or_id.id}"
    else
      item_or_id.to_s
    end
  end
end
