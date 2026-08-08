require "fileutils"
require "pathname"
require "rubygems/package"
require "securerandom"
require "tmpdir"
require "zlib"

class DocusaurusPreviewArtifactInstaller
  class StaleClaimError < StandardError; end

  Artifact = Data.define(:site_path, :claim_token, :source_path, :marker_path)

  MARKER_FILE_NAME = ".docs-portal-preview.json"
  MARKER_VERSION = 1

  class << self
    def installed_artifact_for(version)
      marker_path = version.site_root_absolute_path.join(MARKER_FILE_NAME)
      return if marker_path.size > 16.kilobytes

      marker = JSON.parse(marker_path.read(encoding: "UTF-8"))
      return unless marker["marker_version"] == MARKER_VERSION
      return unless marker["version_public_id"] == version.public_id
      return unless marker["source_path"] == version.source_relative_path
      return if marker["claim_token"].blank?

      site_path = normalize_relative_path(marker["site_path"], label: "Docusaurus site path")
      return unless expected_entry_candidates(version.site_root_absolute_path, site_path).any?(&:file?)

      Artifact.new(
        site_path:,
        claim_token: marker.fetch("claim_token"),
        source_path: marker.fetch("source_path"),
        marker_path:
      )
    rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError, ApplicationError::BadRequest
      nil
    end

    def expected_entry_candidates(root, site_path)
      candidates = [root.join(site_path, "index.html")]
      candidates << root.join("#{site_path}.html")
      candidates << root.join("index.html") if site_path == "index"
      candidates
    end

    def normalize_relative_path(value, label:)
      raw_path = value.to_s.tr("\\", "/")
      invalid_absolute = raw_path.start_with?("/") || raw_path.match?(/\A[A-Za-z]:\//)
      path = raw_path.delete_prefix("./")
      normalized = Pathname.new(path).cleanpath.to_s
      invalid = invalid_absolute || normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
      raise ApplicationError::BadRequest, "#{label} is invalid: #{value}" if invalid

      normalized
    end
  end

  def initialize(version:, archive_path:, site_path:, claim_token: nil)
    @version = version
    @archive_path = archive_path
    @site_path = self.class.normalize_relative_path(site_path, label: "Docusaurus site path")
    @claim_guard = claim_token.present?
    @claim_token = claim_token.presence || SecureRandom.uuid
  end

  def install!
    destination = version.site_root_absolute_path
    FileUtils.mkdir_p(destination.parent)

    Dir.mktmpdir("docusaurus-preview-", destination.parent.to_s) do |tmpdir|
      staging = Pathname.new(tmpdir).join("site")
      FileUtils.mkdir_p(staging)
      extract_archive!(staging)
      raise ApplicationError::BadRequest, "Docusaurus build output missing entry path: #{site_path}" unless expected_entry_exists?(staging)

      write_marker!(staging)
      commit_install!(staging, destination)
    end

    true
  end

  private

  attr_reader :version, :archive_path, :site_path, :claim_token

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
    return if entry.full_name.start_with?("././@")

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
    self.class.expected_entry_candidates(staging, site_path).any?(&:file?)
  end

  def safe_artifact_path(value)
    return if value.to_s.blank? || value.to_s == "."

    self.class.normalize_relative_path(value, label: "Docusaurus build artifact path")
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

  def write_marker!(staging)
    marker = {
      marker_version: MARKER_VERSION,
      version_public_id: version.public_id,
      source_path: version.source_relative_path,
      site_path:,
      claim_token:,
      installed_at: Time.current.iso8601
    }
    staging.join(MARKER_FILE_NAME).write(JSON.generate(marker), encoding: "UTF-8")
  end

  def commit_install!(staging, destination)
    backup = destination.parent.join("#{destination.basename}-backup-#{SecureRandom.hex(6)}")

    version.with_lock do
      version.reload
      verify_current_claim!

      FileUtils.rm_rf(backup)
      FileUtils.mv(destination, backup) if destination.exist?
      FileUtils.mv(staging, destination)
      version.update!(markdown_entry_path: version.source_relative_path, site_build_path: site_path)
      FileUtils.rm_rf(backup)
    rescue StandardError
      restore_backup!(destination, backup)
      raise
    ensure
      FileUtils.rm_rf(backup) if destination.exist? && backup.exist?
    end
  end

  def verify_current_claim!
    return unless @claim_guard
    return if version.preview_running? && version.preview_build_claim_token == claim_token

    raise StaleClaimError, "Docusaurus preview build claim is stale for version #{version.public_id}"
  end

  def restore_backup!(destination, backup)
    return unless backup.exist?

    FileUtils.rm_rf(destination)
    FileUtils.mv(backup, destination)
  end
end
