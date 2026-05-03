require "set"

class DocumentVersionsZipBuilder
  README_ENTRY_NAME = "README.txt"

  def initialize(versions:, user:, filename: "documents.zip")
    @versions = versions
    @user = user
    @filename = filename
  end

  attr_reader :filename

  def entries
    @entries ||= build_entries
  end

  def to_binary
    StoredZipArchive.new(entries.presence || readme_entry).to_binary
  end

  private

  attr_reader :versions, :user

  def build_entries
    used_paths = Set.new

    versions.flat_map do |version|
      version.document_files.order(:sort_order, :file_name).filter_map do |file|
        next unless file.downloadable_by?(user)
        next unless File.file?(file.absolute_path)

        archive_path = unique_path(path_for(version, file), used_paths)
        StoredZipArchive::LocalFileEntry.new(archive_path:, absolute_path: file.absolute_path)
      end
    end
  end

  def path_for(version, file)
    document_dir = safe_segment(version.document.slug)
    version_dir = safe_segment(version.version_label)
    file_path = file.file_name.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(file_path).cleanpath.to_s
    normalized = File.basename(file.file_name.to_s.presence || file.storage_key) if unsafe_path?(normalized)

    File.join(document_dir, version_dir, normalized)
  end

  def unique_path(path, used_paths)
    candidate = path
    basename = File.basename(path, ".*")
    extension = File.extname(path)
    dirname = File.dirname(path)
    index = 2

    while used_paths.include?(candidate)
      candidate = File.join(dirname, "#{basename}-#{index}#{extension}")
      index += 1
    end

    used_paths << candidate
    candidate
  end

  def unsafe_path?(path)
    path.blank? || path == "." || path.start_with?("../") || path.include?("/../")
  end

  def safe_segment(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .gsub(/[\\\/:*?"<>|]/, "-")
      .squish
      .presence || "document"
  end

  def readme_entry
    [
      StoredZipArchive::StringEntry.new(
        archive_path: README_ENTRY_NAME,
        content: "No downloadable files are available for the selected documents.\n"
      )
    ]
  end
end
