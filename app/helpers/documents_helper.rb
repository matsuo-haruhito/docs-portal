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
    ).build(
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

  def tree_item_path(item)
    case item
    when Project
      project_path(item)
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
      item.name
    when DocumentTreeFolderNode
      item.label
    when Document
      document_tree_document_label(item)
    else
      item.to_s
    end
  end

  def tree_item_label_size_class(item)
    length = tree_item_label_full_width_length(tree_item_label(item))

    if length > 25
      "tree-label--length-gt-25"
    elsif length > 20
      "tree-label--length-gt-20"
    elsif length > 15
      "tree-label--length-gt-15"
    end
  end

  def tree_item_tooltip(item)
    case item
    when Project
      item.company&.name
    when DocumentTreeFolderNode
      [item.project.company&.name, item.project.name].compact_blank.join(" / ").presence
    when Document
      document_tree_document_tooltip(item)
    end
  end

  def tree_item_updated_label(item)
    return unless item.is_a?(Document)

    item.updated_at&.strftime("%Y-%m-%d")
  end

  def tree_item_html_available?(item)
    item.is_a?(Document) && document_html_version(item).present?
  end

  def tree_item_css_class(item, current_project: nil, current_document: nil)
    classes = []
    classes << "current-node" if current_tree_item?(item, current_project:, current_document:)
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

  def document_search_match_summaries(document, keyword)
    DocumentSearch.new(keyword).match_summaries_for(document)
  end

  def document_tree_query
    return unless respond_to?(:params)

    params[:tree_query].to_s.squish.presence
  end

  def document_tree_query_match_count(projects, current_project: nil, current_document: nil)
    return 0 if document_tree_query.blank?

    scoped_projects = document_tree_projects_for_query(projects, current_project:, current_document:)
    scoped_projects.sum { |project| document_tree_documents_for(project).size }
  end

  private

  def document_tree_projects_for_query(projects, current_project:, current_document:)
    projects = projects.to_a
    return projects if document_tree_query.blank?

    scoped_project = current_project || current_document&.project
    return projects if scoped_project.blank?

    [scoped_project]
  end

  def current_tree_item?(item, current_project: nil, current_document: nil)
    case item
    when Project
      item.id == current_project&.id || item.id == current_document&.project_id || item == @project
    when Document
      item.id == current_document&.id || item == @document
    else
      false
    end
  end

  def tree_item_label_full_width_length(label)
    label.to_s.each_char.sum { |char| char.ascii_only? ? 0.5 : 1.0 }
  end

  def document_tree_persisted_state
    return unless current_user.respond_to?(:tree_view_state_for)

    current_user.tree_view_state_for(DOCUMENT_TREE_INSTANCE_KEY)
  rescue NameError
    nil
  end

  def tree_toggle_collapsed_icon(item, children)
    return tree_icon("document", title: "子項目はありません") if children.empty?
    return tree_icon("folder_closed", title: "フォルダを開く") if item.is_a?(DocumentTreeFolderNode)

    "+"
  end

  def tree_toggle_expanded_icon(item, children)
    return tree_icon("document", title: "子項目はありません") if children.empty?
    return tree_icon("folder_open", title: "フォルダを閉じる") if item.is_a?(DocumentTreeFolderNode)

    "-"
  end

  def tree_toggle_leaf_icon(item)
    return tree_icon(document_tree_icon_name(item), title: tree_toggle_leaf_icon_title(item)) if item.is_a?(Document)

    "・"
  end

  def tree_toggle_leaf_icon_title(item)
    return "子項目はありません" unless item.is_a?(Document)

    icon_name = document_tree_icon_name(item)
    icon_name == "document" ? "文書" : "#{icon_name} ファイル"
  end

  def tree_icon(icon_name, title: nil)
    safe_icon_name = icon_name.to_s.tr("_", "-")
    tag.svg(
      tag.use(href: "#{asset_path(tree_icon_sprite_asset(icon_name))}#tree-icon-#{safe_icon_name}"),
      class: "tree-icon tree-icon--#{safe_icon_name}",
      viewBox: "0 0 24 24",
      width: 18,
      height: 18,
      title:,
      aria: { hidden: true },
      focusable: false
    )
  end

  def tree_icon_sprite_asset(icon_name)
    return "tree_icons_document.svg" if DOCUMENT_TREE_DOCUMENT_ICON_NAMES.include?(icon_name.to_s)

    DOCUMENT_TREE_EXTRA_ICON_NAMES.include?(icon_name.to_s) ? "tree_icons_extra.svg" : "tree_icons.svg"
  end

  def document_file_icon_name(document_file)
    extension = File.extname(document_file.file_name.to_s).delete_prefix(".").downcase.presence
    return "document" if extension.blank?

    DOCUMENT_TREE_ICON_NAMES.include?(extension) ? extension : "document"
  end

  def document_tree_icon_name(document)
    extension = document_tree_source_extension(document)
    if extension.present?
      normalized_extension = extension.tr(".", "").downcase
      return normalized_extension if DOCUMENT_TREE_ICON_NAMES.include?(normalized_extension)
    end

    case document.document_kind
    when "markdown"
      "md"
    when "pdf"
      "pdf"
    when "excel"
      "xlsx"
    when "word"
      "docx"
    else
      "document"
    end
  end

  def document_tree_source_extension(document)
    version = document_tree_version_for(document)
    extension = version&.source_extension.to_s.delete_prefix(".").presence
    extension ||= File.extname(document_tree_source_file_name(document).to_s).delete_prefix(".").presence
    extension&.downcase
  end

  def document_tree_document_tooltip(document)
    project = document.project
    folder_name = document_tree_source_directory(document).to_s.split("/").last.presence
    version = document_tree_version_for(document)

    [
      project.company&.name,
      project.name,
      folder_name,
      tree_item_updated_label(document)&.then { |label| "最終更新日: #{label}" },
      version&.version_label.presence&.then { |label| "版: #{label}" }
    ].compact_blank.join(" / ").presence
  end

  def prepare_document_tree_cache!(projects)
    query = document_tree_query
    @document_tree_documents_by_project_id = projects.index_with do |project|
      documents = if project.association(:documents).loaded?
        project.documents.to_a
      else
        project.documents.includes(:latest_version, document_versions: :document_files).to_a
      end

      documents = documents.reject { |document| document.archived_at.present? }
      documents = documents.select { |document| document.visible_in_portal_for?(current_user) } unless current_user.internal?
      documents = documents.select { |document| document_tree_query_match?(document, query) } if query.present?
      documents.sort_by { |document| document_tree_document_label(document) }
    end.transform_keys(&:id)
    @document_tree_nodes_by_project_id = {}
    @document_tree_folder_nodes_by_project_and_path = {}
    @document_tree_html_version_by_document_id = {}
    @document_tree_default_site_version_by_project_id = {}
  end

  def document_tree_documents_for(project)
    @document_tree_documents_by_project_id&.fetch(project.id, nil) || begin
      documents = project.documents.accessible_to(current_user).includes(:latest_version, document_versions: :document_files).order(:title).to_a
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

  def document_tree_initial_expansion_state(current_project:, current_document:, expanded_source_path:, collapsed_source_path:)
    expanded_keys = []
    collapsed_keys = []
    expanded_keys << node_key(current_project) if current_project

    opened_source_path = expanded_source_path.presence || collapsed_source_path.presence || document_tree_source_directory(current_document)
    document_tree_folder_ancestor_paths(opened_source_path).each do |path|
      next if collapsed_source_path.present? && path == collapsed_source_path

      folder_node = document_tree_folder_node_for(current_project || current_document&.project, path)
      expanded_keys << node_key(folder_node) if folder_node
    end

    if collapsed_source_path.present?
      folder_node = document_tree_folder_node_for(current_project || current_document&.project, collapsed_source_path)
      collapsed_keys << node_key(folder_node) if folder_node
    end

    { expanded_keys:, collapsed_keys: }
  end

  def document_tree_all_folder_keys_for(project)
    return [] unless project

    document_tree_nodes_for(project)
    (@document_tree_folder_nodes_by_project_and_path&.dig(project.id) || {}).values.map { node_key(_1) }
  end

  def document_tree_query_expanded_keys(projects)
    projects.flat_map do |project|
      documents = document_tree_documents_for(project)
      next [] if documents.empty?

      [
        node_key(project),
        *documents.flat_map do |document|
          document_tree_folder_ancestor_paths(document_tree_source_directory(document)).filter_map do |path|
            folder_node = document_tree_folder_node_for(project, path)
            node_key(folder_node) if folder_node
          end
        end
      ]
    end.uniq
  end

  def document_tree_folder_ancestor_paths(source_path)
    directory = normalize_document_tree_path(source_path)
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
    return unless project && path.present?

    document_tree_nodes_for(project)
    @document_tree_folder_nodes_by_project_and_path&.dig(project.id, path)
  end

  def document_tree_toggle_path(item, action, scope: nil)
    path_options = {
      tree_action: action == :hide ? "hide" : "show",
      tree_query: document_tree_query,
      scope:,
      format: :turbo_stream
    }
    current_window_offset = document_tree_window_request_offset
    path_options[:tree_window_offset] = current_window_offset if current_window_offset.is_a?(Integer)

    case item
    when Project
      project_document_tree_path(
        item,
        node_id: item.id,
        **path_options
      )
    when DocumentTreeFolderNode
      project_document_tree_path(
        item.project,
        source_path: item.path,
        **path_options
      )
    end
  end

  def document_tree_document_label(document)
    document_tree_source_file_name(document).presence || document.title
  end

  def document_tree_query_match?(document, query)
    return true if query.blank?

    normalized_query = query.to_s.downcase
    return false if normalized_query.blank?

    [
      document.title,
      document.slug,
      document_tree_source_file_name(document),
      document_tree_source_directory(document),
      document_tree_version_for(document)&.source_relative_path
    ].compact_blank.any? { |value| value.to_s.downcase.include?(normalized_query) }
  end

  def document_tree_source_directory(document)
    version = document_tree_version_for(document)
    directory = normalize_document_tree_path(version&.source_directory)
    return directory if directory.present?

    relative_path = normalize_document_tree_path(version&.source_relative_path)
    if relative_path.present?
      segments = relative_path.split("/")
      segments.pop
      return segments.join("/")
    end

    file_tree_path = document_tree_primary_file_tree_path(version)
    return if file_tree_path.blank?

    segments = file_tree_path.split("/")
    segments.pop
    segments.join("/")
  end

  def document_tree_source_file_name(document)
    version = document_tree_version_for(document)
    file_name = version&.source_file_name.to_s.presence
    return file_name if file_name.present?

    relative_path = normalize_document_tree_path(version&.source_relative_path)
    return relative_path.split("/").last if relative_path.present?

    file_tree_path = document_tree_primary_file_tree_path(version)
    return if file_tree_path.blank?

    file_tree_path.split("/").last
  end

  def document_tree_version_for(document)
    return unless document

    latest = document.latest_version
    return latest if document_tree_version_has_source_path?(latest)
    return latest if document_tree_version_has_display_file?(latest)

    versions = document.document_versions.to_a

    versions
      .select { |version| document_tree_version_has_source_path?(version) || document_tree_version_has_display_file?(version) }
      .max_by { |version| [version.created_at || Time.zone.at(0), version.id || 0] } ||
      latest ||
      versions.max_by { |version| [version.created_at || Time.zone.at(0), version.id || 0] }
  end

  def document_tree_version_has_source_path?(version)
    version.present? && (
      version.source_directory.present? ||
      version.source_relative_path.present? ||
      version.source_file_name.present?
    )
  end

  def document_tree_version_has_display_file?(version)
    document_tree_primary_file_for(version).present?
  end

  def document_tree_primary_file_tree_path(version)
    document_tree_primary_file_for(version)&.tree_path.to_s.then { normalize_document_tree_path(_1) }.presence
  end

  def document_tree_primary_file_for(version)
    return unless version

    files = version.document_files
    if files.loaded?
      files.to_a.min_by { |file| [file.sort_order || 0, file.id || 0] }
    else
      files.order(:sort_order, :id).first
    end
  end

  def normalize_document_tree_path(path)
    path.to_s.tr("\\", "/").split("/").reject(&:blank?).join("/")
  end

  def project_default_site_path(project)
    version = @document_tree_default_site_version_by_project_id&.fetch(project.id, nil)
    unless @document_tree_default_site_version_by_project_id&.key?(project.id)
      version = document_tree_documents_for(project)
        .filter_map(&:latest_version)
        .select { _1.rendered_site_available? && _1.viewable_by?(current_user) }
        .max_by(&:published_at)
      @document_tree_default_site_version_by_project_id[project.id] = version if @document_tree_default_SITE_VERSION_by_project_id
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

  def document_tree_render_window_offset(visible_rows:, current_document:, requested_offset:)
    max_offset = [visible_rows.length - DOCUMENT_TREE_RENDER_WINDOW_LIMIT, 0].max

    if requested_offset.is_a?(Integer) && requested_offset >= 0
      return [requested_offset, max_offset].min
    end

    current_index = document_tree_visible_row_index_for(visible_rows, current_document)
    return 0 unless current_index

    desired_offset = [current_index - (DOCUMENT_TREE_RENDER_WINDOW_LIMIT / 2), 0].max
    [desired_offset, max_offset].min
  end

  def document_tree_visible_row_index_for(visible_rows, current_document)
    return unless current_document

    current_key = node_key(current_document)
    visible_rows.index { |row| row.node_key == current_key }
  end

  def document_tree_window_request_offset
    return unless respond_to?(:params)

    raw_offset = params[:tree_window_offset]
    return if raw_offset.blank?

    parsed_offset = Integer(raw_offset)
    parsed_offset if parsed_offset >= 0
  rescue ArgumentError, TypeError
    nil
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
