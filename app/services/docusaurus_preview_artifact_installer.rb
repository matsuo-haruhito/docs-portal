require "fileutils"
require "rubygems/package"
require "zlib"

class DocusaurusPreviewArtifactInstaller
  def initialize(version:, archive_path:, site_path:)
    @version = version
    @archive_path = archive_path
    @site_path = site_path
  end

  def install!
    destination = version.site_root_absolute_path
    FileUtils.mkdir_p(destination)
    FileUtils.rm_rf(destination.children)

    Zlib::GzipReader.open(archive_path) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          extract_entry(entry, destination)
        end
      end
    end

    expected_entry = destination.join(site_path, "index.html")
    raise ApplicationError::BadRequest, "Docusaurus build output missing entry path: #{site_path}" unless expected_entry.exist?

    version.update!(markdown_entry_path: version.source_relative_path, site_build_path: site_path)
  end

  private

  attr_reader :version, :archive_path, :site_path

  def extract_entry(entry, destination)
    relative_path = safe_relative_path(entry.full_name)
    return if relative_path.blank?

    target = safe_destination(destination, relative_path)

    if entry.directory?
      FileUtils.mkdir_p(target)
    elsif entry.file?
      FileUtils.mkdir_p(target.dirname)
      File.open(target, "wb") do |file|
        IO.copy_stream(entry, file)
      end
    end
  end

  def safe_relative_path(value)
    path = value.to_s.tr("\\", "/").delete_prefix("./").delete_prefix("/")
    return nil if path.blank? || path == "."

    normalized = Pathname.new(path).cleanpath.to_s
    invalid = normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "Docusaurus build artifact contains invalid path: #{value}" if invalid

    normalized
  end

  def safe_destination(root, relative_path)
    target = root.join(relative_path).cleanpath
    root_path = root.expand_path.to_s
    target_path = target.expand_path.to_s

    unless target_path == root_path || target_path.start_with?(root_path + File::SEPARATOR)
      raise ApplicationError::BadRequest, "Docusaurus build artifact path escapes destination: #{relative_path}"
    end

    target
  end
end
