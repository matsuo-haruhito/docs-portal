module ProjectsHelper
  def project_document_detail_tree_nodes(documents)
    root_nodes = []
    folder_nodes_by_path = {}

    documents.each do |document|
      directory = document_tree_source_directory(document).to_s
      if directory.blank?
        root_nodes << { type: :document, document: }
        next
      end

      parent_nodes = root_nodes
      path_segments = []
      directory.split("/").reject(&:blank?).each do |segment|
        path_segments << segment
        path = path_segments.join("/")
        folder_node = folder_nodes_by_path[path]
        unless folder_node
          folder_node = { type: :folder, path:, label: segment, children: [] }
          folder_nodes_by_path[path] = folder_node
          parent_nodes << folder_node
        end
        parent_nodes = folder_node[:children]
      end
      parent_nodes << { type: :document, document: }
    end

    sort_project_document_detail_tree_nodes!(root_nodes)
    root_nodes
  end

  private

  def sort_project_document_detail_tree_nodes!(nodes)
    nodes.sort_by! do |node|
      if node[:type] == :folder
        [0, node[:label].to_s]
      else
        [1, tree_item_label(node[:document]).to_s]
      end
    end

    nodes.each do |node|
      sort_project_document_detail_tree_nodes!(node[:children]) if node[:type] == :folder
    end
  end
end
