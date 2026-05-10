require "fileutils"

class GitImportManifestBuilder
  Result = Data.define(:artifact_root, :manifest_path, :manifest, :summary)

  def initialize(source:, worktree_path:, commit_sha:)
    @source = source
    @worktree_path = Pathname.new(worktree_path)
    @commit_sha = commit_sha
  end

  def call
    artifact_root = DocumentImporter::IMPORT_ROOT.join("git_pull", @source.public_id, @commit_sha)
    attachments_root = artifact_root.join("attachments")
    FileUtils.rm_rf(artifact_root)
    FileUtils.mkdir_p(attachments_root)

    scan_result = ZipImportDocumentScanner.new(root: @worktree_path, candidate_policy: :renderable_only).call
    documents = scan_result.documents.map do |candidate|
      document_payload_for(candidate, attachments_root)
    end
    deleted_candidates = deleted_candidates_for(documents)
    manifest = {
      source_repo: @source.repository_full_name,
      source_branch: @source.branch,
      source_commit_hash: @commit_sha,
      documents: documents
    }

    manifest_path = artifact_root.join("manifest.json")
    File.write(manifest_path, JSON.pretty_generate(manifest))

    Result.new(
      artifact_root: artifact_root,
      manifest_path: manifest_path,
      manifest: manifest,
      summary: {
        documents: documents.size,
        attachments: documents.sum { _1.fetch(:files).size },
        deleted_candidates: deleted_candidates,
        source_path: @source.normalized_source_path,
        commit_sha: @commit_sha,
        warnings: scan_result.warnings
      }
    )
  end

  private

  def document_payload_for(candidate, attachments_root)
    source_relative_path = File.join(@source.normalized_source_path, candidate.logical_path)
    classification = DocumentClassificationSuggester.new.suggest(
      source_path: source_relative_path,
      file_name: File.basename(candidate.logical_path),
      frontmatter: candidate.frontmatter
    )

    {
      project_code: @source.project.code,
      slug: candidate.slug,
      title: candidate.title,
      category: classification.attributes[:category] || "spec",
      document_kind: classification.attributes[:document_kind] || candidate.document_kind,
      visibility_policy: classification.attributes[:visibility_policy] || "restricted_external",
      version_label: version_label,
      status: "published",
      source_relative_path: source_relative_path,
      snapshot_kind: classification.attributes[:snapshot_kind] || "git_import",
      changelog_summary: "Imported from #{@source.repository_full_name}@#{@commit_sha.first(12)}",
      files: candidate.attachment_paths.each_with_index.map { |path, index| copy_attachment(path, attachments_root, index) }
    }.compact
  end

  def copy_attachment(path, attachments_root, index)
    source_path = Pathname(path)
    relative_path = source_path.relative_path_from(@worktree_path).to_s.tr("\\", "/")
    storage_key = File.join("git_imports", @source.public_id, @commit_sha, relative_path)
    destination = attachments_root.join(storage_key)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(source_path, destination)

    {
      file_name: relative_path,
      content_type: content_type_for(source_path),
      storage_key: storage_key,
      file_size: source_path.size,
      sort_order: index
    }
  end

  def content_type_for(path)
    ZipImport::PathClassifier.new(root: @worktree_path).content_type_for(path)
  end

  def deleted_candidates_for(documents)
    project = @source.project
    return [] unless project && project.persisted?
    return [] unless @source.class.exists?(id: @source.id)

    imported_paths = documents.map { _1.fetch(:source_relative_path) }
    existing_paths = project.documents.includes(:latest_version).filter_map { _1.latest_version&.source_relative_path }
    existing_paths.grep(%r{\A#{Regexp.escape(@source.normalized_source_path)}/}).sort - imported_paths.sort
  end

  def version_label
    "git-#{@commit_sha.first(12)}"
  end
end
