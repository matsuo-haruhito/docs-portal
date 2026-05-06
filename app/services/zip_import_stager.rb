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
    copy_uploaded_zip!
    extract_zip!
    scan_result = ZipImportDocumentScanner.new(root: extracted_root).call
    manifest = build_manifest(scan_result)
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

  def copy_uploaded_zip!
    io = uploaded_io
    io.rewind if io.respond_to?(:rewind)
    File.open(zip_path, "wb") do |file|
      IO.copy_stream(io, file)
    end
  end

  def extract_zip!
    entry_count = 0
    total_bytes = 0
    extracted_paths = []

    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        next if entry.directory?

        entry_count += 1
        raise ApplicationError::BadRequest, "ZIP contains too many files" if entry_count > MAX_ENTRY_COUNT

        safe_path = safe_relative_path(entry.name)
        total_bytes += entry.size
        raise ApplicationError::BadRequest, "ZIP is too large after extraction" if total_bytes > MAX_TOTAL_UNCOMPRESSED_BYTES

        destination = extracted_root.join(safe_path)
        FileUtils.mkdir_p(destination.dirname)
        entry.extract(destination.to_s) { true }
        extracted_paths << destination
      end
    end

    extracted_paths
  rescue Zip::Error => e
    raise ApplicationError::BadRequest, "ZIP extraction failed: #{e.message}"
  end

  def build_manifest(scan_result)
    {
      source_repo:,
      source_branch:,
      source_commit_hash: provided_source_commit_hash || Digest::SHA256.file(zip_path).hexdigest,
      documents: scan_result.documents.map { manifest_document_for(_1) },
      zip_import_preview: {
        orphan_files: scan_result.orphan_files,
        skipped_files: scan_result.skipped_files,
        warnings: scan_result.warnings
      }
    }
  end

  def manifest_document_for(candidate)
    classification = DocumentClassificationSuggester.new.suggest(
      source_path: candidate.logical_path,
      file_name: File.basename(candidate.logical_path),
      frontmatter: candidate.frontmatter
    )

    {
      project_code: project.code,
      slug: candidate.slug,
      title: candidate.title,
      category: classification.attributes[:category] || "spec",
      document_kind: classification.attributes[:document_kind] || candidate.document_kind,
      visibility_policy: classification.attributes[:visibility_policy] || "restricted_external",
      version_label:,
      status:,
      source_relative_path: candidate.logical_path,
      snapshot_kind: classification.attributes[:snapshot_kind],
      files: candidate.attachment_paths.each_with_index.map { |path, index| manifest_file_for(candidate, path, index) }
    }.compact
  end

  def manifest_file_for(candidate, path, index)
    logical_path = path.relative_path_from(extracted_root).to_s.tr("\\", "/")
    storage_key = File.join(
      "zip_uploads",
      staging_key,
      candidate.slug,
      version_label,
      logical_path
    )
    destination = artifact_root.join("attachments", storage_key)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(path, destination)

    {
      file_name: path.basename.to_s,
      content_type: ZipImportDocumentScanner.new(root: extracted_root).content_type_for(path),
      storage_key:,
      file_size: path.size,
      sort_order: index
    }
  end

  def safe_relative_path(raw_path)
    normalized = raw_path.to_s.tr("\\", "/").delete_prefix("/")
    path = Pathname.new(normalized).cleanpath.to_s
    invalid = path.blank? || path == "." || path == ".." || path.start_with?("../") || path.include?("/../")
    raise ApplicationError::BadRequest, "ZIP entry path is invalid: #{raw_path}" if invalid

    path.split("/").map { FileNameNormalizer.new(_1, fallback: "file").call }.join("/")
  end

  def uploaded_io
    if uploaded_file.respond_to?(:tempfile)
      uploaded_file.tempfile
    elsif uploaded_file.respond_to?(:read)
      uploaded_file
    else
      raise ApplicationError::BadRequest, "zip_file is invalid"
    end
  end

  def original_file_name
    uploaded_file.respond_to?(:original_filename) ? uploaded_file.original_filename.to_s : "upload.zip"
  end
end
