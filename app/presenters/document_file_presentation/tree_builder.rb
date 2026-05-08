module DocumentFilePresentation
  class TreeBuilder
    Node = Data.define(:id, :parent_node_id, :label, :document_file, :directory) do
      def directory?
        directory
      end

      def file?
        !directory?
      end
    end

    def initialize(files:)
      @files = Array(files)
    end

    def call
      directory_nodes = {}
      nodes = []

      files.sort_by { [path_for(_1), _1.sort_order, _1.file_name.to_s] }.each do |file|
        parts = path_for(file).split("/")
        parent_node_id = nil

        parts[0...-1].each_with_index do |segment, index|
          path = parts.first(index + 1).join("/")
          node = directory_nodes[path] ||= Node.new(
            id: "dir:#{path}",
            parent_node_id: parent_node_id,
            label: segment,
            document_file: nil,
            directory: true
          )
          nodes << node unless nodes.include?(node)
          parent_node_id = node.id
        end

        nodes << Node.new(
          id: "file:#{file.public_id}",
          parent_node_id: parent_node_id,
          label: parts.last,
          document_file: file,
          directory: false
        )
      end

      nodes
    end

    private

    attr_reader :files

    def path_for(file)
      file.tree_path
    end
  end
end
