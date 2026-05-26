require "digest"

module DocumentsHelper
  DocumentTreeFolderNode = Data.define(:project, :path, :label, :children)
  DOCUMENT_TREE_INSTANCE_KEY = "documents:sidebar"
  DOCUMENT_TREE_RENDER_WINDOW_THRESHOLD = 80
  DOCUMENT_TREE_RENDER_WINDOW_LIMIT = 50
  DOCUMENT_TREE_ICON_NAMES = %w[
    7z ai company_lit company_unlit css csv doc document docx fig folder_closed folder_open gz htm html ini jpeg jpg json key log md mdx odp ods odt pages parquet pdf png ppt pptx psd rst rtf svg tar tex tif tiff toml tsv txt webp xls xlsm xlsx xml yaml yml zip
  ].freeze
  DOCUMENT_TREE_EXTRA_ICON_NAMES = %w[
    odp ods odt pages parquet psd rst rtf tar tex tif tiff toml tsv txt webp
  ].freeze
  DOCUMENT_TREE_DOCUMENT_ICON_NAMES = %w[doc document].freeze

  def document_tree_render_state(projects:, current_project: nil, current_document: nil, expanded_source_path: nil, collapsed_source_path: nil)
    projects = document_tree_projects_for_query(projects, current_project:, current_document:)
    prepare_document_tree_cache!(projects)

    adapter = TreeView::GraphAdapter.new(
      roots: [*projects],
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
    toolbar_project = current_project || current_document&.project
    ui_config = TreeView::UiConfigBuilder.new(
      context: self,
      node_prefix: "document_tree",
      key_resolver: ->(item_or_id) { node_key(item_or_id) }
    ).build_turbo(
      hide_descendants_path_builder: ->(item, _depth, scope) { document_tree_toggle_path(item, :hide, scope:) },
      show_descendants_path_builder: ->(item, _depth, scope) { document_tree_toggle_path(item, :show, scope:) },
      toggle_all_path_builder: ->(state) { document_tree_toggle_all_path(state, current_project: toolbar_project, current_document:) }
    )

    expansion_state = document_tree_initial_expansion_state(
      current_project:,
      current_document:,
      expanded_source_path:,
      collapsed_source_path:
    )

    persisted_state = document_tree_persisted_state
    expanded_keys = (Array(persisted_state&.expanded_keys) + expansion_state.fetch(:expanded_keys, [])).uniq
    if current_document.present? && Array(persisted_state&.expanded_keys).blank?
      expanded_keys |= document_tree_all_folder_keys_for(current_document.project)
    end
    expanded_keys |= document_tree_query_expanded_keys(projects) if document_tree_query.present?
    collapsed_keys = expansion_state.fetch(:collapsed_keys, [])
    expanded_keys -= collapsed_keys

    render_state = TreeView::RenderState.new(
      tree:,
      root_items: tree.root_items,
      row_partial: "documents/tree_columns",
      ui_config:,
      tree_instance_key: DOCUMENT_TREE_INSTANCE_KEY,
      initial_expansion: { default: :collapsed, expanded_keys:, collapsed_keys: },
      toggle_icon_builder: ->(item, state, context) { tree_toggle_button_label(item, state, context) },
      row_class_builder: ->(item) { tree_item_css_class(item, current_project:, current_document:) },
      row_data_builder: ->(item) { tree_item_data_attributes(item) }
    )
    render_state.define_singleton_method(:expanded_keys) { expanded_keys } unless render_state.respond_to?(:expanded_keys)
    render_state
  end

  def document_tree_render_window(render_state, current_document: nil, requested_offset: document_tree_window_request_offset)
    visible_rows = TreeView::VisibleRows.new(
      tree: render_state.tree,
      root_items: render_state.root_items,
      render_state: render_state
    ).to_a
    return if visible_rows.length <= DOCUMENT_TREE_RENDER_WINDOW_THRESHOLD

    TreeView::RenderWindow.new(
      visible_rows,
      offset: document_tree_render_window_offset(
        visible_rows:,
        current_document:,
        requested_offset:
      ),
      limit: DOCUMENT_TREE_RENDER_WINDOW_LIMIT
    )
  end

  def document_tree_window_path(project:, current_document: nil, offset:)
    project_document_tree_path(
      project,
      document_slug: current_document&.slug,
      tree_query: document_tree_query,
      tree_window_offset: offset,
      format: :turbo_stream
    )
  end

  def document_tree_toggle_all_path(state, current_project: nil, current_document: nil)
    project = current_project || current_document&.project
    return unless project

    tree_action =
      case state.to_sym
      when :expanded, :show
        "show"
      when :collapsed, :hide
        "hide"
      end
    return unless tree_action

    path_options = {
      tree_action:,
      tree_query: document_tree_query,
      format: :turbo_stream
    }
    current_window_offset = document_tree_window_request_offset
    path_options[:tree_window_offset] = current_window_offset if current_window_offset.is_a?(Integer)

    document_tree_all_project_path(project, **path_options)
  end

  def tree_toggle_button_label(item, state, context)
    children = Array(context[:children])

    case state.to_sym
    when :collapsed
      { html: tree_toggle_collapsed_icon(item, children), class: "tree-toggle__icon--open", title: "開く" }
    when :expanded
      { html: tree_toggle_expanded_icon(item, children), class: "tree-toggle__icon--close", title: "閉じる" }
    else
      { html: tree_toggle_leaf_icon(item), class: "tree-toggle__icon--leaf", title: tree_toggle_leaf_icon_title(item) }
    end
  end

  def document_file_icon(document_file, title: nil)
    tree_icon(document_file_icon_name(document_file), title: title || document_file.file_name)
  end

  def tree_icon(name, title: nil)
    safe_join([
      image_tag("file_icons/#{name}.svg", alt: "", width: 16, height: 16, class: "tree-node-icon tree-node-icon--image"),
      content_tag(:span, title || name.to_s.humanize, class: "sr-only")
    ])
  end

  def project_tree_icon(project)
    if project.archived?
      tree_icon("company_unlit", title: "アーカイブ済み案件")
    else
      tree_icon("company_lit", title: "案件")
    end
  end

  def document_tree_toggle_path(item, action, scope: nil)
    return unless item.is_a?(DocumentTreeFolderNode)

    project_document_tree_toggle_path(
      item.project,
      tree_action: action,
      source_path: item.path,
      tree_scope: scope,
      document_slug: document_tree_current_document_slug,
      tree_query: document_tree_query,
      tree_window_offset: document_tree_window_request_offset,
      format: :turbo_stream
    )
  end

  def document_tree_current_document_slug
    params[:document_slug].presence || params.dig(:document, :slug).presence
  end

  def document_tree_query
    params[:tree_query].to_s.strip.presence
  end

  def document_tree_window_request_offset
    Integer(params[:tree_window_offset], exception: false)
  end

  def document_tree_query_match_count(projects, current_project: nil, current_document: nil)
    projects = document_tree_projects_for_query(projects, current_project:, current_document:)
    projects.sum { document_tree_project_documents(_1).size }
  end

  def document_tree_projects_for_query(projects, current_project: nil, current_document: nil)
    projects = Array(projects)
    query = document_tree_query
    return projects unless query.present?

    active_project = current_project || current_document&.project
    return projects unless active_project

    matching_documents = document_tree_project_documents(active_project)
    return [active_project] if matching_documents.any?

    [active_project]
  end

  def tree_toggle_collapsed_icon(item, children)
    return tree_toggle_leaf_icon(item) if children.empty?

    case item
    when Project
      project_tree_icon(item)
    when DocumentTreeFolderNode
      tree_icon("folder_closed", title: "フォルダを開く")
    else
      tree_toggle_leaf_icon(item)
    end
  end

  def tree_toggle_expanded_icon(item, children)
    return tree_toggle_leaf_icon(item) if children.empty?

    case item
    when Project
      project_tree_icon(item)
    when DocumentTreeFolderNode
      tree_icon("folder_open", title: "フォルダを閉じる")
    else
      tree_toggle_leaf_icon(item)
    end
  end

  def tree_toggle_leaf_icon(item)
    case item
    when Project
      project_tree_icon(item)
    when Document
      tree_icon(document_tree_icon_name(item), title: tree_item_label(item))
    when DocumentTreeFolderNode
      tree_icon("folder_closed", title: item.label)
    else
      tree_icon("document", title: tree_item_label(item))
    end
  end

  def tree_toggle_leaf_icon_title(item)
    case item
    when Project
      "案件"
    when Document
      tree_item_label(item)
    when DocumentTreeFolderNode
      item.label
    else
      tree_item_label(item)
    end
  end

  def tree_item_label(item)
    case item
    when Project
      item.name
    when Document
      item.title.presence || item.slug
    when DocumentTreeFolderNode
      item.label
    else
      item.to_s
    end
  end

  def tree_item_css_class(item, current_project: nil, current_document: nil)
    classes = ["document-tree__row"]
    classes << "document-tree__project-row" if item.is_a?(Project)
    classes << "document-tree__folder-row" if item.is_a?(DocumentTreeFolderNode)
    classes << "document-tree__document-row" if item.is_a?(Document)
    classes << "document-tree__row--active-project" if current_project && item == current_project
    classes << "document-tree__row--active-document" if current_document && item == current_document
    classes
  end

  def tree_item_data_attributes(item)
    return {} unless item.is_a?(Document)

    {
      document_slug: item.slug,
      source_path: document_tree_source_path(item)
    }
  end

  def document_tree_icon_name(document)
    version = document.respond_to?(:latest_version) ? document.latest_version : nil
    extension = version&.source_extension.to_s.downcase.delete_prefix(".")
    file_name = version&.source_file_name.to_s
    basename = version&.source_basename.to_s
    return "document" if extension.blank? && file_name.blank?

    candidate_names = []
    candidate_names << extension if extension.present?
    candidate_names << File.extname(file_name).delete_prefix(".").downcase if file_name.present?
    candidate_names << File.extname(basename).delete_prefix(".").downcase if basename.present?
    candidate_names = candidate_names.reject(&:blank?).uniq

    icon_name = candidate_names.find { DOCUMENT_TREE_ICON_NAMES.include?(_1) }
    return icon_name if icon_name.present?

    if candidate_names.any? { DOCUMENT_TREE_EXTRA_ICON_NAMES.include?(_1) }
      candidate_names.find { DOCUMENT_TREE_EXTRA_ICON_NAMES.include?(_1) }
    else
      "document"
    end
  end

  def document_file_icon_name(document_file)
    extension = document_file.extension.to_s.downcase.delete_prefix(".")
    file_name = document_file.file_name.to_s

    if extension.present? && DOCUMENT_TREE_ICON_NAMES.include?(extension)
      extension
    elsif file_name.present?
      extracted_extension = File.extname(file_name).delete_prefix(".").downcase
      if extracted_extension.present? && DOCUMENT_TREE_ICON_NAMES.include?(extracted_extension)
        extracted_extension
      else
        "document"
      end
    else
      "document"
    end
  end

  def prepare_document_tree_cache!(projects)
    @document_tree_nodes_by_project_id = {}
    @document_tree_documents_by_project_id = {}
    @document_tree_folder_keys_by_project_id = {}

    Array(projects).each do |project|
      next unless project.is_a?(Project)

      documents = project.documents.includes(:latest_version).order(:title).to_a
      @document_tree_documents_by_project_id[project.id] = documents
      nodes = document_tree_nodes_from_documents(project, documents)
      @document_tree_nodes_by_project_id[project.id] = nodes
      @document_tree_folder_keys_by_project_id[project.id] = document_tree_folder_keys(nodes)
    end
  end

  def document_tree_nodes_for(project)
    @document_tree_nodes_by_project_id&.fetch(project.id, []) || []
  end

  def document_tree_project_documents(project)
    @document_tree_documents_by_project_id&.fetch(project.id, []) || []
  end

  def document_tree_folder_keys(nodes)
    nodes.flat_map do |node|
      if node.is_a?(DocumentTreeFolderNode)
        [node_key(node), *document_tree_folder_keys(node.children)]
      else
        []
      end
    end
  end

  def document_tree_all_folder_keys_for(project)
    @document_tree_folder_keys_by_project_id&.fetch(project.id, []) || []
  end

  def document_tree_nodes_from_documents(project, documents)
    root_nodes = []
    folder_nodes = {}

    documents.each do |document|
      directory = document_tree_source_directory(document)
      if directory.blank?
        root_nodes << document
        next
      end

      segments = directory.split("/").reject(&:blank?)
      parent_nodes = root_nodes
      current_path = []

      segments.each do |segment|
        current_path << segment
        path = current_path.join("/")
        folder_node = folder_nodes[path]
        unless folder_node
          folder_node = DocumentTreeFolderNode.new(project:, path:, label: segment, children: [])
          folder_nodes[path] = folder_node
          parent_nodes << folder_node
        end
        parent_nodes = folder_node.children
      end

      parent_nodes << document
    end

    sort_document_tree_nodes!(root_nodes)
    root_nodes
  end

  def document_tree_source_directory(document)
    document.latest_version&.source_directory.to_s
  end

  def document_tree_source_path(document)
    version = document.respond_to?(:latest_version) ? document.latest_version : nil
    path = version&.source_relative_path.to_s.presence
    return path if path.present?

    directory = version&.source_directory.to_s.presence
    file_name = version&.source_file_name.to_s.presence
    if directory.present? && file_name.present?
      File.join(directory, file_name)
    else
      file_name.to_s
    end
  end

  def document_tree_search_tokens(document)
    version = document.respond_to?(:latest_version) ? document.latest_version : nil
    [
      document.title,
      document.slug,
      version&.source_relative_path,
      version&.source_directory,
      version&.source_file_name,
      version&.source_basename
    ].filter_map { _1.to_s.downcase.presence }
  end

  def document_tree_query_matches?(document, query)
    return true if query.blank?

    tokens = document_tree_search_tokens(document)
    normalized_query = query.to_s.downcase
    tokens.any? { _1.include?(normalized_query) }
  end

  def document_tree_query_expanded_keys(projects)
    active_project = projects.find { _1.is_a?(Project) }
    return [] unless active_project

    matching_documents = document_tree_project_documents(active_project).select { document_tree_query_matches?(_1, document_tree_query) }
    matching_documents.flat_map do |document|
      keys = [node_key(document)]
      directory = document_tree_source_directory(document)
      next keys if directory.blank?

      segments = directory.split("/").reject(&:blank?)
      current_path = []
      folder_keys = segments.map do |segment|
        current_path << segment
        node_key(DocumentTreeFolderNode.new(project: active_project, path: current_path.join("/"), label: segment, children: []))
      end
      keys + folder_keys
    end.uniq
  end

  def document_tree_initial_expansion_state(current_project: nil, current_document: nil, expanded_source_path: nil, collapsed_source_path: nil)
    expanded_keys = []
    collapsed_keys = []

    active_project = current_project || current_document&.project
    expanded_keys << node_key(active_project) if active_project
    expanded_keys.concat(document_tree_folder_keys_for_source_path(active_project, current_document&.latest_version&.source_relative_path || current_document&.latest_version&.source_directory)) if active_project && current_document
    expanded_keys.concat(document_tree_folder_keys_for_source_path(active_project, expanded_source_path)) if active_project && expanded_source_path.present?
    collapsed_keys.concat(document_tree_folder_keys_for_source_path(active_project, collapsed_source_path)) if active_project && collapsed_source_path.present?

    { expanded_keys: expanded_keys.compact.uniq, collapsed_keys: collapsed_keys.compact.uniq }
  end

  def document_tree_folder_keys_for_source_path(project, source_path)
    return [] if project.blank? || source_path.blank?

    path_segments = source_path.to_s.split("/").reject(&:blank?)
    return [] if path_segments.empty?

    directory_segments = if source_path.to_s.end_with?("/")
      path_segments
    else
      path_segments[0...-1]
    end

    keys = []
    current_path = []
    directory_segments.each do |segment|
      current_path << segment
      keys << node_key(DocumentTreeFolderNode.new(project:, path: current_path.join("/"), label: segment, children: []))
    end
    keys
  end

  def document_tree_persisted_state
    return unless current_user.respond_to?(:tree_view_state_for)

    current_user.tree_view_state_for(DOCUMENT_TREE_INSTANCE_KEY)
  end

  def sort_document_tree_nodes!(nodes)
    nodes.sort_by! do |node|
      case node
      when Project
        [0, node.name.to_s]
      when DocumentTreeFolderNode
        [1, node.label.to_s]
      when Document
        [2, tree_item_label(node).to_s]
      else
        [3, node.to_s]
      end
    end

    nodes.each do |node|
      sort_document_tree_nodes!(node.children) if node.is_a?(DocumentTreeFolderNode)
    end
  end

  def node_key(item_or_id)
    case item_or_id
    when Project
      "project_#{item_or_id.id}"
    when DocumentTreeFolderNode
      "document_tree_folder_#{item_or_id.project.id}_#{Digest::SHA256.hexdigest(item_or_id.path).first(16)}"
    when Document
      "document_#{item_or_id.id}"
    else
      if item_or_id.respond_to?(:id) && item_or_id.class.name.present?
        "#{item_or_id.class.name.underscore}_#{item_or_id.id}"
      else
        item_or_id.to_s
      end
    end
  end
end
