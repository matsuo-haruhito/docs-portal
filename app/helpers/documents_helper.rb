require "digest"

module DocumentsHelper
  DocumentTreeFolderNode = Data.define(:project, :path, :label, :children)

  def document_tree_render_state(projects:, current_project: nil, current_document: nil)
    projects = projects.to_a
    prepare_document_tree_cache!(projects)

    adapter = TreeView::GraphAdapter.new(
      roots: projects,
      children_resolver: lambda do |node|
        case node
        when Project
          document_tree_nodes_for(node)
        when DocumentTreeFolderNode
          node.children
        else
          []
        end
      end,
      node_key_resolver: ->(node) { node_key(node) }
    )

    tree = TreeView::Tree.new(adapter:)
    ui_config = TreeView::UiConfigBuilder.new(
      context: self,
      node_prefix: "document_tree",
      key_resolver: ->(item_or_id) { node_key(item_or_id) }
    ).build_client_side

    expanded_keys = document_tree_initial_expanded_keys(
      current_project:,
      current_document:
    )

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
    when DocumentTreeFolderNode
      project_documents_path(item.project, q: item.path)
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
    when DocumentTreeFolderNode
      item.label
    when Document
      document_tree_document_label(item)
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
    classes << "tree-folder-node" if item.is_a?(DocumentTreeFolderNode)
    classes << "html-unavailable" if item.is_a?(Document) && !tree_item_html_available?(item)
    classes
  end

  def tree_item_data_attributes(item)
    case item
    when Project
      {
        tree_item_type: item.class.name.underscore,
        tree_item_id: item.id,
        project_id: item.id
      }
    when DocumentTreeFolderNode
      {
        tree_item_type: "document_tree_folder",
        tree_item_id: node_key(item),
        project_id: item.project.id,
        source_path: item.path
      }
    when Document
      {
        tree_item_type: item.class.name.underscore,
        tree_item_id: item.id,
        project_id: item.project_id,
        html_available: tree_item_html_available?(item)
      }
    else
      {}
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
      documents.sort_by { |document| document_tree_document_label(document) }
    end.transform_keys(&:id)
    @document_tree_nodes_by_project_id = {}
    @document_tree_folder_nodes_by_project_and_path = {}
    @document_tree_html_version_by_document_id = {}
    @document_tree_default_site_version_by_project_id = {}
  end

  def document_tree_documents_for(project)
    @document_tree_documents_by_project_id&.fetch(project.id, nil) || begin
      documents = project.documents.accessible_to(current_user).includes(:latest_version).order(:title).to_a
      current_user.internal? ? documents : documents.select { _1.visible_in_portal_for?(current_user) }
    end
  end

  def document_tree_nodes_for(project)
    @document_tree_nodes_by_project_id&.fetch(project.id, nil) || build_document_tree_nodes_for(project)
  end

  def build_document_tree_nodes_for(project)
    root_nodes = []
    folder_nodes_by_path = {}

    document_tree_documents_for(project).each do |document|
      directory = document.latest_version&.source_directory.to_s
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
          folder_node = DocumentTreeFolderNode.new(
            project:,
            path:,
            label: segment,
            children: []
          )
          folder_nodes_by_path[path] = folder_node
          parent_nodes << folder_node
        end
        parent_nodes = folder_node.children
      end
      parent_nodes << document
    end

    sort_document_tree_nodes!(root_nodes)
    @document_tree_folder_nodes_by_project_and_path[project.id] = folder_nodes_by_path if @document_tree_folder_nodes_by_project_and_path
    @document_tree_nodes_by_project_id[project.id] = root_nodes if @document_tree_nodes_by_project_id
    root_nodes
  end

  def sort_document_tree_nodes!(nodes)
    nodes.sort_by! do |node|
      case node
      when DocumentTreeFolderNode
        [0, node.label.to_s]
      when Document
        [1, document_tree_document_label(node)]
      else
        [2, node.to_s]
      end
    end

    nodes.each do |node|
      sort_document_tree_nodes!(node.children) if node.is_a?(DocumentTreeFolderNode)
    end
  end

  def document_tree_initial_expanded_keys(current_project:, current_document:)
    keys = []
    keys << node_key(current_project) if current_project

    document_tree_folder_ancestor_paths(current_document).each do |path|
      folder_node = document_tree_folder_node_for(current_document.project, path)
      keys << node_key(folder_node) if folder_node
    end

    keys
  end

  def document_tree_folder_ancestor_paths(document)
    directory = document&.latest_version&.source_directory.to_s
    return [] if directory.blank?

    paths = []
    segments = []
    directory.split("/").reject(&:blank?).each do |segment|
      segments << segment
      paths << segments.join("/")
    end
    paths
  end

  def document_tree_folder_node_for(project, path)
    document_tree_nodes_for(project)
    @document_tree_folder_nodes_by_project_and_path&.dig(project.id, path)
  end

  def document_tree_document_label(document)
    document.latest_version&.source_file_name.presence || document.title
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
    case item_or_id
    when DocumentTreeFolderNode
      "folder_#{item_or_id.project.id}_#{Digest::SHA256.hexdigest(item_or_id.path).first(16)}"
    else
      if item_or_id.respond_to?(:id)
        "#{item_or_id.class.name.underscore}_#{item_or_id.id}"
      else
        item_or_id.to_s
      end
    end
  end
end
