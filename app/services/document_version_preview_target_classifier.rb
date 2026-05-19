class DocumentVersionPreviewTargetClassifier
  Classification = Data.define(:file, :role, :group_name, :hidden, :debug) do
    def tree_path
      file.tree_path
    end

    def primary?
      role == :primary
    end

    def attachment?
      role == :attachment
    end

    def hidden?
      hidden
    end

    def debug?
      debug
    end

    def grouped?
      group_name.present?
    end

    def visible?
      !hidden?
    end
  end

  def initialize(document_version, metadata: nil)
    @document_version = document_version
    @metadata_result = metadata
  end

  def call
    document_files.map do |file|
      Classification.new(
        file:,
        role: role_for(file),
        group_name: group_name_for(file),
        hidden: hidden_path?(file.tree_path),
        debug: debug_path?(file.tree_path)
      )
    end
  end

  private

  attr_reader :document_version, :metadata_result

  def document_files
    @document_files ||= document_version.document_files.order(:sort_order, :id).to_a
  end

  def metadata
    @metadata ||= (metadata_result || DocumentVersionPreviewTargetMetadata.new(document_version).call).metadata
  end

  def role_for(file)
    path = file.tree_path
    return :primary if path.in?(paths_for("primary"))
    return :attachment if path.in?(paths_for("attachments"))
    return :debug if path.in?(paths_for("debug"))
    return :hidden if path.in?(paths_for("hidden"))
    return :grouped if group_name_for(file).present?

    :normal
  end

  def group_name_for(file)
    groups.find { |_group, paths| file.tree_path.in?(paths) }&.first
  end

  def hidden_path?(path)
    path.in?(paths_for("hidden"))
  end

  def debug_path?(path)
    path.in?(paths_for("debug"))
  end

  def paths_for(key)
    Array(metadata[key])
  end

  def groups
    Hash(metadata["groups"]).transform_values { Array(_1) }
  end
end
