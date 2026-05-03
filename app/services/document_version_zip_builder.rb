class DocumentVersionZipBuilder
  README_ENTRY_NAME = "README.txt"

  def initialize(version:, user:)
    @version = version
    @user = user
  end

  def filename
    [
      version.document.slug,
      version.version_label
    ].map { sanitize_filename_component(_1) }.join("-") + ".zip"
  end

  def entries
    source_files + readme_entry
  end

  def empty?
    source_files.empty?
  end

  def to_binary
    StoredZipArchive.new(entries).to_binary
  end

  private

  attr_reader :version, :user

  def source_files
    @source_files ||= version.document_files.order(:sort_order, :file_name).filter_map do |file|
      next unless file.downloadable_by?(user)
      next unless File.file?(file.absolute_path)

      StoredZipArchive::LocalFileEntry.new(
        archive_path: archive_path_for(file),
        absolute_path: file.absolute_path
      )
    end
  end

  def readme_entry
    return [] if source_files.any?

    [
      StoredZipArchive::StringEntry.new(
        archive_path: README_ENTRY_NAME,
        content: "No downloadable files are available for #{version.document.title} #{version.version_label}.\n"
      )
    ]
  end

  def archive_path_for(file)
    path = file.file_name.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path).cleanpath.to_s

    if normalized.blank? || normalized == "." || normalized.start_with?("../") || normalized.include?("/../")
      return File.basename(file.file_name.to_s.presence || file.storage_key)
    end

    normalized
  end

  def sanitize_filename_component(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .gsub(/[\\\/:*?"<>|]/, "-")
      .squish
      .presence || "document"
  end
end
