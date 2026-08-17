# frozen_string_literal: true

module DocumentFilePresentation
  # PathTreeBuilder を使って document_file のツリーを構築する。
  # view partial は item.directory? / item.file? / item.document_file / item.label を使う。
  class TreeBuilder
    def initialize(files:)
      @files = Array(files)
    end

    def call
      return [] if files.empty?

      builder.nodes
    end

    def tree
      builder.tree
    end

    private

    attr_reader :files

    def builder
      @builder ||= TreeView::PathTreeBuilder.new(
        records: sorted_files,
        path_resolver: ->(file) { file.tree_path },
        label_resolver: ->(file) { File.basename(file.tree_path) },
        id_resolver: ->(file) { "file:#{file.public_id}" },
        folder_key_prefix: "dir",
        sort: { folders_first: true }
      )
    end

    def sorted_files
      files.sort_by { |file| [file.tree_path, file.sort_order, file.file_name.to_s] }
    end
  end
end
