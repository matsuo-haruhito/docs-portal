require "digest"
require "fileutils"
require "securerandom"
require "zip"

class ZipImportStager
  MAX_ENTRY_COUNT = 2_000
  MAX_TOTAL_UNCOMPRESSED_BYTES = 200.megabytes

  Result = Data.define(:artifact_root, :manifest_path, :manifest, :scan_result)

  def initialize(uploaded_file:, project:, actor:, source_repo: nil, source_branch: nil, source_commit_hash: nil, version_label: nil, status: nil)
    @uploaded_file = uploaded_file
    @project = project
    @actor = actor
    @source_repo = source_repo.presence || "zip_upload"
    @source_branch = source_branch.presence || original_file_name
    @version_label = version_label.presence || "zip-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    @status = status.presence || "published"
    @staging_key = SecureRandom.hex(10)
    @provided_source_commit_hash = source_commit_hash.presence
  end

  def call
    prepare_directories!
    ZipImport::ArchiveExtractor.new(
      uploaded_file:,
      zip_path:,
      extracted_root:,
      max_entry_count: MAX_ENTRY_COUNT,
      max_total_uncompressed_bytes: MAX_TOTAL_UNCOMPRESSED_BYTES
    ).call
    scan_result = ZipImportDocumentScanner.new(root: extracted_root).call
    manifest = ZipImport::ManifestBuilder.new(
      scan_result:,
      extracted_root:,
      artifact_root:,
      project:,
      source_repo:,
      source_branch:,
      source_commit_hash: provided_source_commit_hash || Digest::SHA256.file(zip_path).hexdigest,
      version_label:,
      status:,
      staging_key:
    ).call
    manifest_path = artifact_root.join("manifest.json")
    File.write(manifest_path, JSON.pretty_generate(manifest))

    Result.new(
      artifact_root: artifact_root,
      manifest_path:,
      manifest:,
      scan_result:
    )
  rescue
    FileUtils.rm_rf(staging_root) if staging_root&.exist?
    raise
  end

  private

  attr_reader :uploaded_file, :project, :actor, :source_repo, :source_branch, :version_label, :status, :staging_key, :provided_source_commit_hash

  def staging_root
    @staging_root ||= DocumentImporter::IMPORT_ROOT.join("zip_uploads", staging_key)
  end

  def zip_path
    staging_root.join("source.zip")
  end

  def extracted_root
    staging_root.join("extracted")
  end

  def artifact_root
    staging_root.join("artifact")
  end

  def prepare_directories!
    FileUtils.mkdir_p(extracted_root)
    FileUtils.mkdir_p(artifact_root.join("attachments"))
  end

  def original_file_name
    uploaded_file.respond_to?(:original_filename) ? uploaded_file.original_filename.to_s : "upload.zip"
  end
end
