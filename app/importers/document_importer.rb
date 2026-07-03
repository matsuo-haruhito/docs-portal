require "fileutils"
require "securerandom"

class DocumentImporter
  IMPORT_ROOT = Rails.root.join("storage", "imports")
  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze

  attr_reader :artifact_root, :manifest_path, :manifest

  def initialize(artifact_root:, manifest_path:, actor:, change_event_notifier: GeneratedFiles::ChangeEventNotifier.new)
    @import_root = import_root_path
    @artifact_root = resolve_allowed_path!(artifact_root, type: :directory)
    @manifest_path = resolve_allowed_path!(manifest_path, type: :file)
    ensure_manifest_under_artifact_root!
    @manifest = JSON.parse(File.read(@manifest_path))
    @actor = actor
    @change_event_notifier = change_event_notifier
    @generated_file_events = []
  end

  def call
    publish_job = PublishJob.create!(
      source_repo: manifest.fetch("source_repo"),
      source_branch: manifest.fetch("source_branch"),
      source_commit_hash: manifest.fetch("source_commit_hash"),
      artifact_path: artifact_root.to_s,
      status: :pending
    )

    manifest.fetch("documents", []).each do |doc_payload|
      import_document!(doc_payload)
    end

    publish_job.update!(status: :imported, log_message: "Imported successfully")
    dispatch_generated_file_change_event!(publish_job)
    publish_job
  rescue => e
    publish_job&.update!(status: :failed, log_message: e.message)
    raise
  end

  private

  attr_reader :change_event_notifier, :generated_file_events

  def import_document!(payload)
    project = Project.find_by!(code: payload.fetch("project_code"))

    imported_version = Document.transaction do
      document = resolve_document(project, payload)
      operation = document.new_record? ? "create" : "update"
      document.assign_attributes(
        title: payload.fetch("title"),
        category: payload.fetch("category"),
        document_kind: payload.fetch("document_kind"),
        visibility_policy: payload.fetch("visibility_policy")
      )
      document.save!

      version = build_document_version(document, payload)
      return unless version

      existing_document_files = version.persisted? ? version.document_files.to_a : []

      version.assign_attributes(
        status: payload.fetch("status"),
        source_commit_hash: manifest.fetch("source_commit_hash"),
        changelog_summary: payload["changelog_summary"],
        published_at: published_at_for(payload),
        published_by_user: @actor,
        markdown_entry_path: payload["markdown_entry_path"],
        site_build_path: payload["site_build_path"],
        pdf_snapshot_path: payload["pdf_snapshot_path"]
      )
      assign_source_path_metadata!(version, payload)
      version.save!

      sync_site_build!(version)
      replace_document_files!(version, Array(payload["files"]), existing_document_files)

      document.update!(latest_version: version) if version.published?
      record_generated_file_event!(source_path_for(payload), operation)
      version
    end

    enqueue_preview_build!(imported_version) if imported_version && markdown_version?(imported_version)
  end

  def build_document_version(document, payload)
    version_label = payload["version_label"].presence
    return build_versioned_document_version(document, version_label) if version_label.present?

    overwrite_document_version_for(document)
  end

  def build_versioned_document_version(document, version_label)
    if document.document_versions.exists?(version_label: version_label)
      raise ArgumentError, "Document version already exists: #{document.slug} #{version_label}"
    end

    document.document_versions.build(version_label: version_label)
  end

  def overwrite_document_version_for(document)
    document.latest_version || document.document_versions.order(created_at: :desc, id: :desc).first ||
      raise(ArgumentError, "version_label is required for a new document import: #{document.slug}")
  end

  def replace_document_files!(version, files, existing_document_files)
    new_storage_keys = []

    files.each_with_index do |file_payload, idx|
      normalized_storage_key = copy_attachment!(file_payload.fetch("storage_key"))
      new_storage_keys << normalized_storage_key

      version.document_files.create!(
        file_name: file_payload.fetch("file_name"),
        content_type: file_payload.fetch("content_type"),
        storage_key: normalized_storage_key,
        file_size: file_payload.fetch("file_size"),
        sort_order: idx
      )
    end

    existing_document_files.each do |document_file|
      delete_attachment_file!(document_file) unless new_storage_keys.include?(document_file.storage_key)
      document_file.destroy!
    end
  end

  def delete_attachment_file!(document_file)
    FileUtils.rm_f(document_file.absolute_path)
  end

  def resolve_document(project, payload)
    resolver = DocumentImportTargetResolver.new(project:)
    source_path = source_path_for(payload)
    slug = payload["slug"]
    resolver.call(source_path:, slug:) || project.documents.build(slug: slug.presence || fallback_slug_for(source_path))
  end

  def assign_source_path_metadata!(version, payload)
    source_path = source_path_for(payload)
    return if source_path.blank?

    version.assign_source_path_metadata!(
      source_path: source_path,
      snapshot_kind: payload["snapshot_kind"]
    )
  end

  def source_path_for(payload)
    payload["source_relative_path"].presence ||
      payload["source_path"].presence ||
      payload["markdown_entry_path"].presence ||
      payload["pdf_snapshot_path"].presence ||
      payload["site_build_path"].presence
  end

  def fallback_slug_for(source_path)
    base = source_path.to_s.presence || "document"
    base = Pathname(base).sub_ext("").to_s
    normalized = base.split("/").map { |segment| segment.parameterize.presence || "part" }.join("-")
    normalized.presence || "document"
  end

  def published_at_for(payload)
    return Time.zone.parse(payload["published_at"]) if payload["published_at"].present?
    return Time.current if payload["status"] == "published"

    nil
  end

  def sync_site_build!(version)
    if version.site_build_path.blank?
      FileUtils.rm_rf(version.site_root_absolute_path)
      return
    end

    copy_site_build!(version)
  end

  def copy_site_build!(version)
    source = @artifact_root.join("docusaurus", "build")
    raise ArgumentError, "Docusaurus build directory not found" unless source.exist?

    destination = version.site_root_absolute_path
    FileUtils.mkdir_p(destination.parent)
    staging = destination.parent.join("#{destination.basename}-staging-#{SecureRandom.hex(4)}")

    FileUtils.rm_rf(staging)
    FileUtils.mkdir_p(staging)
    FileUtils.cp_r(source.children, staging)

    staged_entry = staging.join(version.site_entry_relative_path)
    unless staged_entry.exist?
      raise ArgumentError, "Site build path not found in copied build: #{version.site_build_path}"
    end

    FileUtils.rm_rf(destination)
    FileUtils.mv(staging, destination)
  ensure
    FileUtils.rm_rf(staging) if defined?(staging) && staging&.exist?
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

  def enqueue_preview_build!(version)
    version.mark_preview_build_queued!
    DocusaurusPreviewBuildJob.perform_later(version.id)
  end

  def markdown_version?(version)
    File.extname(version.source_relative_path.to_s).downcase.in?(MARKDOWN_EXTENSIONS)
  end

  def dispatch_generated_file_change_event!(publish_job)
    return if generated_file_events.empty?

    change_event_notifier.notify(
      file_events: generated_file_events.uniq.sort_by { [_1.fetch(:path), _1.fetch(:operation)] },
      event_source: "artifact_import",
      metadata: {
        publish_job_id: publish_job.id,
        actor_id: @actor&.id,
        source_repo: manifest["source_repo"],
        source_branch: manifest["source_branch"],
        source_commit_hash: manifest["source_commit_hash"]
      }.compact
    )
  end

  def record_generated_file_event!(path, operation)
    generated_file_events << { path: path.to_s, operation: operation.to_s }
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

  def ensure_manifest_under_artifact_root!
    artifact_root_with_separator = "#{@artifact_root}#{File::SEPARATOR}"
    return if @manifest_path.to_s.start_with?(artifact_root_with_separator)

    raise ApplicationError::Forbidden, "Manifest path is outside the artifact root"
  end

  def normalize_storage_key!(storage_key)
    value = storage_key.to_s
    raise ApplicationError::BadRequest, "storage_key is required" if value.blank?
    raise ApplicationError::BadRequest, "storage_key contains invalid characters" if value.include?("\0")
    raise ApplicationError::BadRequest, "storage_key must be a relative path" if value.start_with?("/")

    normalized = Pathname.new(value).cleanpath.to_s
    invalid_relative_path = normalized.start_with?("../") || normalized == "." || normalized == ".."
    raise ApplicationError::BadRequest, "storage_key must be a relative path" if invalid_relative_path

    normalized
  end
end
