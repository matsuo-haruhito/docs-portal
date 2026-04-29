require "fileutils"

class DocImportService
  def initialize(artifact_root:, manifest_path:, actor:)
    @artifact_root = Pathname.new(artifact_root)
    @manifest = JSON.parse(File.read(manifest_path))
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
        copy_attachment!(f.fetch("storage_key"))

        version.document_files.create!(
          file_name: f.fetch("file_name"),
          content_type: f.fetch("content_type"),
          storage_key: f.fetch("storage_key"),
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
    source = @artifact_root.join("attachments", storage_key)
    raise ArgumentError, "Attachment not found: #{storage_key}" unless source.exist?

    destination = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(destination.parent)
    FileUtils.cp(source, destination)
  end
end
