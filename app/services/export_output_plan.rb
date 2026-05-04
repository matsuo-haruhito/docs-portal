class ExportOutputPlan
  Item = Data.define(:document, :document_version, :document_file, :zip_path, :output_file_name, :watermark_text) do
    def source_path
      document_version&.source_relative_path
    end
  end

  Result = Data.define(:project, :viewer, :items) do
    def zip_paths
      items.map(&:zip_path)
    end

    def output_file_names
      items.map(&:output_file_name)
    end
  end

  def initialize(project:, viewer:, files:, base_path: nil, include_source_path: true, watermark: true, generated_at: Time.current)
    @project = project
    @viewer = viewer
    @files = Array(files)
    @base_path = base_path
    @include_source_path = include_source_path
    @watermark = watermark
    @generated_at = generated_at
  end

  def call
    Result.new(project:, viewer:, items: files.map { item_for(_1) })
  end

  private

  attr_reader :project, :viewer, :files, :base_path, :include_source_path, :watermark, :generated_at

  def item_for(file)
    version = file.document_version
    document = version.document
    output_file_name = safe_file_name(file.file_name)

    Item.new(
      document:,
      document_version: version,
      document_file: file,
      zip_path: zip_path_for(version, output_file_name),
      output_file_name:,
      watermark_text: watermark ? watermark_text_for(document) : nil
    )
  end

  def zip_path_for(version, output_file_name)
    segments = []
    segments << base_path.to_s.strip if base_path.present?
    segments << File.dirname(version.source_relative_path.to_s) if include_source_path && version&.source_relative_path.present?
    segments << output_file_name

    segments.reject(&:blank?).join("/").gsub(%r{/+}, "/")
  end

  def safe_file_name(file_name)
    file_name.to_s.tr("\\/", "_").presence || "document-file"
  end

  def watermark_text_for(document)
    [
      "Confidential",
      viewer.company&.name,
      viewer.email_address,
      project.code,
      document.public_id,
      generated_at.strftime("%Y-%m-%d %H:%M")
    ].compact.join(" - ")
  end
end
