module DocumentsHelper
  def document_tree_render_state(projects:)
    adapter = TreeView::GraphAdapter.new(
      roots: projects,
      children_resolver: lambda do |node|
        if node.is_a?(Project)
          node.documents.accessible_to(current_user).includes(:latest_version).order(:title)
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
      project_default_site_path(item) || project_path(item)
    when Document
      document_html_path(item) || project_document_path(item.project, item.slug)
    end
  end

  def tree_item_detail_path(item)
    case item
    when Project
      project_path(item)
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

  def tree_item_updated_label(item)
    return unless item.is_a?(Document)

    item.updated_at&.strftime("%Y-%m-%d")
  end

  def tree_item_html_available?(item)
    item.is_a?(Document) && document_html_version(item).present?
  end

  def tree_item_css_class(item)
    classes = []
    classes << "current-node" if item == @project || item == @document
    classes << "html-unavailable" if item.is_a?(Document) && !tree_item_html_available?(item)
    classes.join(" ")
  end

  def document_search_match_labels(document, keyword)
    DocumentSearch.new(keyword).match_labels_for(document)
  end

  private

  def project_default_site_path(project)
    version = project.default_site_version_for(current_user)
    return unless version

    project_site_path(project, site_path: version.html_view_site_path, version_id: version.public_id)
  end

  def document_html_path(document)
    version = document_html_version(document)
    return unless version

    project_site_path(document.project, site_path: version.html_view_site_path, version_id: version.public_id)
  end

  def document_html_version(document)
    version = document.latest_version
    return unless version&.rendered_site_available?
    return unless version.viewable_by?(current_user)

    version
  end

  def node_key(item_or_id)
    if item_or_id.respond_to?(:id)
      "#{item_or_id.class.name.underscore}_#{item_or_id.id}"
    else
      item_or_id.to_s
    end
  end
end
