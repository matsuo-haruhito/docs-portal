require "fileutils"
require "pathname"
require "rubygems/package"
require "tmpdir"
require "zlib"

class DocusaurusPreviewArtifactInstaller
  def initialize(version:, archive_path:, site_path:)
    @version = version
    @archive_path = archive_path
    @site_path = safe_site_path(site_path)
  end

  def install!
    destination = version.site_root_absolute_path
    FileUtils.mkdir_p(destination.parent)

    Dir.mktmpdir("docusaurus-preview-", destination.parent.to_s) do |tmpdir|
      staging = Pathname.new(tmpdir).join("site")
      FileUtils.mkdir_p(staging)
      extract_archive!(staging)
      raise ApplicationError::BadRequest, "Docusaurus build output missing entry path: #{site_path}" unless expected_entry_exists?(staging)

      FileUtils.rm_rf(destination)
      FileUtils.mv(staging, destination)
    end

    version.update!(markdown_entry_path: version.source_relative_path, site_build_path: site_path)
  end

  private

  attr_reader :version, :archive_path, :site_path

  def extract_archive!(destination)
    Zlib::GzipReader.open(archive_path) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          extract_entry(entry, destination)
        end
      end
    end
  end

  def extract_entry(entry, destination)
    relative_path = safe_artifact_path(entry.full_name)
    return if relative_path.blank?

    target = safe_destination(destination, relative_path)

    if entry.directory?
      FileUtils.mkdir_p(target)
    elsif entry.file?
      FileUtils.mkdir_p(target.dirname)
      File.open(target, "wb") do |file|
        IO.copy_stream(entry, file)
      end
    else
      raise ApplicationError::BadRequest, "Docusaurus build artifact contains unsupported entry type: #{entry.full_name}"
    end
  end

  def expected_entry_exists?(staging)
    expected_entry_candidates(staging).any?(&:exist?)
  end

  def expected_entry_candidates(staging)
    candidates = [staging.join(site_path, "index.html")]
    candidates << staging.join("#{site_path}.html")
    candidates << staging.join("index.html") if site_path == "index"
    candidates
  end

  def safe_site_path(value)
    normalized = normalized_relative_path(value, label: "Docusaurus site path")
    if normalized.blank? || normalized == "."
      raise ApplicationError::BadRequest, "Docusaurus site path is invalid: #{value}"
    end

    normalized
  end

  def safe_artifact_path(value)
    normalized = normalized_relative_path(value, label: "Docusaurus build artifact path")
    return nil if normalized.blank? || normalized == "."

    normalized
  end

  def normalized_relative_path(value, label:)
    raw_path = value.to_s.tr("\\", "/")
    invalid_absolute = raw_path.start_with?("/") || raw_path.match?(/\A[A-Za-z]:\//)
    path = raw_path.delete_prefix("./")
    normalized = Pathname.new(path).cleanpath.to_s
    invalid = invalid_absolute || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "#{label} is invalid: #{value}" if invalid

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
