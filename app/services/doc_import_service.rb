require "fileutils"

class DocImportService
  IMPORT_ROOT = Rails.root.join("storage", "imports")

  def initialize(artifact_root:, manifest_path:, actor:)
    @import_root = import_root_path
    @artifact_root = resolve_allowed_path!(artifact_root, type: :directory)
    @manifest_path = resolve_allowed_path!(manifest_path, type: :file)
    @manifest = JSON.parse(File.read(@manifest_path))
    @actor = actor
  end

  def call
    publish_job = PublishJob.create!(
      source_repo: @manifest.fetch("source_repo"),
      source_branch: @manifest.fetch("source_branch"),
      source_commit_hash: @manifest.fetch("source_commit_hash"),
      artifact_path: @artifact_root.to_s,
      status: :pending
    )

    @manifest.fetch("documents", []).each do |doc_payload|
      import_document!(doc_payload)
    end

    publish_job.update!(status: :imported, log_message: "Imported successfully")
    publish_job
  rescue => e
    publish_job&.update!(status: :failed, log_message: e.message)
    raise
  end

  private

  def import_document!(payload)
    project = Project.find_by!(code: payload.fetch("project_code"))

    Document.transaction do
      document = project.documents.find_or_initialize_by(slug: payload.fetch("slug"))
      document.assign_attributes(
        title: payload.fetch("title"),
        category: payload.fetch("category"),
        document_kind: payload.fetch("document_kind"),
        visibility_policy: payload.fetch("visibility_policy")
      )
      document.save!

      version_label = payload.fetch("version_label")
      if document.document_versions.exists?(version_label: version_label)
        raise ArgumentError, "Document version already exists: #{document.slug} #{version_label}"
      end

      version = document.document_versions.create!(
        version_label: version_label,
        status: payload.fetch("status"),
        source_commit_hash: @manifest.fetch("source_commit_hash"),
        changelog_summary: payload["changelog_summary"],
        published_at: published_at_for(payload),
        published_by_user: @actor,
        markdown_entry_path: payload["markdown_entry_path"],
        site_build_path: payload["site_build_path"],
        pdf_snapshot_path: payload["pdf_snapshot_path"]
      )

      copy_site_build!(version)

      Array(payload["files"]).each_with_index do |f, idx|
        normalized_storage_key = copy_attachment!(f.fetch("storage_key"))

        version.document_files.create!(
          file_name: f.fetch("file_name"),
          content_type: f.fetch("content_type"),
          storage_key: normalized_storage_key,
          file_size: f.fetch("file_size"),
          sort_order: idx
        )
      end

      document.update!(latest_version: version) if version.published?
    end
  end

  def published_at_for(payload)
    return Time.zone.parse(payload["published_at"]) if payload["published_at"].present?
    return Time.current if payload["status"] == "published"

    nil
  end

  def copy_site_build!(version)
    return if version.site_build_path.blank?

    source = @artifact_root.join("docusaurus", "build")
    raise ArgumentError, "Docusaurus build directory not found" unless source.exist?

    destination = version.site_root_absolute_path
    FileUtils.mkdir_p(destination)
    FileUtils.rm_rf(destination.children)
    FileUtils.cp_r(source.children, destination)

    unless version.site_entry_absolute_path&.exist?
      raise ArgumentError, "Site build path not found in copied build: #{version.site_build_path}"
    end
  end

  def copy_attachment!(storage_key)
    normalized_storage_key = normalize_storage_key!(storage_key)
    source = @artifact_root.join("attachments", normalized_storage_key)
    raise ArgumentError, "Attachment not found: #{storage_key}" unless source.exist?

    destination = Rails.root.join("storage", "document_files", normalized_storage_key)
    FileUtils.mkdir_p(destination.parent)
    FileUtils.cp(source, destination)
    normalized_storage_key
  end

  def import_root_path
    IMPORT_ROOT.realpath
  rescue Errno::ENOENT
    raise ApplicationError::Forbidden, "Import root is not available"
  end

  def resolve_allowed_path!(path, type:)
    resolved = Pathname.new(path).realpath
    ensure_under_import_root!(resolved)

    case type
    when :directory
      raise ActiveRecord::RecordNotFound, "Directory not found: #{path}" unless resolved.directory?
    when :file
      raise ActiveRecord::RecordNotFound, "File not found: #{path}" unless resolved.file?
    end

    resolved
  rescue Errno::ENOENT
    raise ActiveRecord::RecordNotFound, "#{type == :directory ? 'Directory' : 'File'} not found: #{path}"
  end

  def ensure_under_import_root!(resolved_path)
    import_root_with_separator = "#{@import_root}#{File::SEPARATOR}"
    return if resolved_path.to_s == @import_root.to_s
    return if resolved_path.to_s.start_with?(import_root_with_separator)

    raise ApplicationError::Forbidden, "Path is outside the allowed import root"
  end

  def normalize_storage_key!(storage_key)
    value = storage_key.to_s
    raise ApplicationError::BadRequest, "storage_key is required" if value.blank?
    raise ApplicationError::BadRequest, "storage_key contains invalid characters" if value.include?("\0")
    raise ApplicationError::BadRequest, "storage_key must be a relative path" if value.start_with?("/")

    normalized = Pathname.new(value).cleanpath.to_s
    raise ApplicationError::BadRequest, "storage_key must be a relative path" if normalized.start_with?("../")

    normalized
  end
end
