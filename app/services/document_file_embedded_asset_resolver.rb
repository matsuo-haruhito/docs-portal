class DocumentFileEmbeddedAssetResolver
  def initialize(owner_file:, requested_asset_path:)
    @owner_file = owner_file
    @requested_asset_path = requested_asset_path
  end

  def call
    normalized_asset_path = normalize_path(requested_asset_path)
    return if normalized_asset_path.blank?

    owner_file.document_version.document_files.detect do |candidate|
      normalize_path(candidate.tree_path) == normalized_asset_path
    end
  end

  private

  attr_reader :owner_file, :requested_asset_path

  def normalize_path(value)
    path = value.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path.presence || ".").cleanpath.to_s
    return if normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../")

    normalized
  end
end
