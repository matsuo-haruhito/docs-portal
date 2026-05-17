class DocumentFileAssetBasePath
  def initialize(file:, current_tree_path:, path_builder:)
    @file = file
    @current_tree_path = current_tree_path
    @path_builder = path_builder
  end

  def call
    asset_path = [current_directory, "."].compact_blank.join("/")
    path_builder.call(file, asset_path:).sub(%r{/\.\z}, "")
  end

  private

  attr_reader :file, :current_tree_path, :path_builder

  def current_directory
    directory = File.dirname(current_tree_path.to_s)
    directory == "." ? nil : directory
  end
end
