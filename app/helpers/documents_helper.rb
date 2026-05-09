module DocumentsHelper
  def document_tree_render_state(projects:, current_project: nil)
    projects = projects.to_a
    prepare_document_tree_cache!(projects)

    adapter = TreeView::GraphAdapter.new(
      roots: [*projects],
      children_resolver: lambda do |node|
        node.is_a?(Project) ? document_tree_documents_for(node) : []
      end,
      node_key_resolver: ->(node) { node_key(node) }
    )

    tree = TreeView::Tree.new(adapter:)
    ui_config = TreeView::UiConfigBuilder.new(
      context: self,
      node_prefix: "document_tree",
      key_resolver: ->(item_or_id) { node_key(item_or_id) }
    ).build(
      hide_descendants_path_builder: ->(item, _depth, scope) { document_tree_toggle_path(item, :hide, scope:) },
      show_descendants_path_builder: ->(item, _depth, scope) { document_tree_toggle_path(item, :show, scope:) },
      toggle_all_path_builder: ->(_state) { nil }
    )

    expanded_keys = current_project ? [node_key(current_project)] : []

    TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial: "documents/tree_columns",
      ui_config:,
      initial_expansion: { default: :collapsed, expanded_keys: },
      toggle_icon_builder: ->(item, state, context) { tree_toggle_button_label(item, state, context) },
      row_class_builder: ->(item) { tree_item_css_class(item) },
      row_data_builder: ->(item) { tree_item_data_attributes(item) }
    )
  end

  def tree_toggle_button_label(item, state, context)
    children = Array(context[:children])
    return { text: "・", class: "tree-toggle__icon--leaf", title: "子項目はありません" } if children.empty?

    case state.to_sym
    when :collapsed
      { text: "開く", class: "tree-toggle__icon--open", title: "展開" }
    when :expanded
      { text: "閉じる", class: "tree-toggle__icon--close", title: "折りたたむ" }
    else
      { text: "・", class: "tree-toggle__icon--leaf", title: "子項目はありません" }
    end
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
    classes
  end

  def tree_item_data_attributes(item)
    base_data = {
      tree_item_type: item.class.name.underscore,
      tree_item_id: item.id
    }

    case item
    when Project
      base_data.merge(project_id: item.id)
    when Document
      base_data.merge(
        project_id: item.project_id,
        html_available: tree_item_html_available?(item)
      )
    else
      base_data
    end
  end

  def document_search_match_labels(document, keyword)
    DocumentSearch.new(keyword).match_labels_for(document)
  end

  private

  def prepare_document_tree_cache!(projects)
    @document_tree_documents_by_project_id = projects.index_with do |project|
      documents = if project.association(:documents).loaded?
        project.documents.to_a
      else
        project.documents.includes(:latest_version).to_a
      end

      documents = documents.reject { |document| document.archived_at.present? }
      documents = documents.select { |document| document.visible_in_portal_for?(current_user) } unless current_user.internal?
      documents.sort_by { |document| document.title.to_s }
    end.transform_keys(&:id)
    @document_tree_html_version_by_document_id = {}
    @document_tree_default_site_version_by_project_id = {}
  end

  def document_tree_documents_for(project)
    @document_tree_documents_by_project_id&.fetch(project.id, nil) || begin
      documents = project.documents.accessible_to(current_user).includes(:latest_version).order(:title).to_a
      current_user.internal? ? documents : documents.select { _1.visible_in_portal_for?(current_user) }
    end
  end

  def document_tree_toggle_path(item, action, scope: nil)
    return unless item.is_a?(Project)

    project_document_tree_path(
      item,
      node_id: item.id,
      tree_action: action == :hide ? "hide" : "show",
      scope:,
      format: :turbo_stream
    )
  end

  def project_default_site_path(project)
    version = @document_tree_default_site_version_by_project_id&.fetch(project.id, nil)
    unless @document_tree_default_site_version_by_project_id&.key?(project.id)
      version = document_tree_documents_for(project)
        .filter_map(&:latest_version)
        .select { _1.rendered_site_available? && _1.viewable_by?(current_user) }
        .max_by(&:published_at)
      @document_tree_default_site_version_by_project_id[project.id] = version if @document_tree_default_site_version_by_project_id
    end
    return unless version

    project_site_path(project, site_path: version.html_view_site_path, version_id: version.public_id)
  end

  def document_html_path(document)
    version = document_html_version(document)
    return unless version

    project_site_path(document.project, site_path: version.html_view_site_path, version_id: version.public_id)
  end

  def document_html_version(document)
    cached = @document_tree_html_version_by_document_id&.fetch(document.id, nil)
    return cached if @document_tree_html_version_by_document_id&.key?(document.id)

    version = document.latest_version
    version = nil unless version&.rendered_site_available?
    version = nil unless version&.viewable_by?(current_user)
    @document_tree_html_version_by_document_id[document.id] = version if @document_tree_html_version_by_document_id
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
